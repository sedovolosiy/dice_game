require 'digest'
require 'securerandom'
require 'sinatra' # Add sinatra
require 'json' # Add json for easier data handling
require 'sqlite3' # Add sqlite3

# Configure Sinatra
set :bind, '0.0.0.0' # Bind to all interfaces
set :port, 4567       # Set port

# Database setup
DB = SQLite3::Database.new "dice_game.db"
DB.execute <<~SQL
  CREATE TABLE IF NOT EXISTS users (
    email TEXT PRIMARY KEY,
    last_nonce INTEGER DEFAULT 0
  );
SQL

class DiceGame
  HOUSE_EDGE = 0.01 # 1% house edge

  def calculate_dynamic_edge(target_number)
    base_edge = 0.01 # minimum commission
    extra_edge = [(target_number - 50) * 0.002, 0].max
    base_edge + extra_edge
  end

  def initialize
    @server_seed = SecureRandom.hex(32)
    @server_seed_hash = Digest::SHA256.hexdigest(@server_seed)
  end

  def get_server_seed_hash
    @server_seed_hash
  end

  def calculate_payout_multiplier(target_number)
    edge = calculate_dynamic_edge(target_number)
    # Ensure floating point division
    (100.0 / target_number.to_f) * (1.0 - edge)
  end

  def play(email, client_seed, target_number, bet_amount) # Signature changed
    # 1. Input validation
    raise "Invalid target number. Must be between 1 and 99." unless (1..99).include?(target_number)
    raise "Invalid bet amount. Must be a positive number." unless bet_amount.is_a?(Numeric) && bet_amount > 0

    # Verify user and manage nonce from database
    user = DB.execute("SELECT last_nonce FROM users WHERE email = ?", email).first
    raise "User not found or not verified. Please verify your email first." if user.nil?
    
    last_nonce = user[0]
    current_nonce = last_nonce + 1 # Auto-increment nonce

    # Corrected DB.execute call: pass bind parameters as an array
    DB.execute("UPDATE users SET last_nonce = ? WHERE email = ?", [current_nonce, email])

    # 2. Random number generation
    combined_string = "#{@server_seed}:#{client_seed}:#{current_nonce}"
    hash = Digest::SHA512.hexdigest(combined_string) # SHA512 for better security
    random_number = hash.to_i(16) % 100 + 1 # Number from 1 to 100

    # 3. Result determination
    win = random_number <= target_number # Use target_number
    payout = 0.0
    if win
      multiplier = calculate_payout_multiplier(target_number)
      payout = (bet_amount * multiplier).round(2) # Calculate and round payout
    end

    # 4. Return result, server seed, and used nonce
    {
      win: win,
      number: random_number,
      server_seed: @server_seed,
      nonce: current_nonce, # Return the nonce used
      payout: payout, # New: return calculated payout
      target_number: target_number, # For clarity in result
      bet_amount: bet_amount      # For clarity in result
    }
  end

  def verify(server_seed, client_seed, bet, nonce, expected_number) # 'bet' here is target_number
    # 1. Recalculate random number
    combined_string = "#{server_seed}:#{client_seed}:#{nonce}"
    hash = Digest::SHA512.hexdigest(combined_string)
    random_number = hash.to_i(16) % 100 + 1

    # 2. Check for match
    if random_number == expected_number
      return true
    else
      return false
    end
  end
end

# Test multiplier outputs for verification
puts "Target: 50 => Multiplier: #{DiceGame.new.calculate_payout_multiplier(50).round(2)}"
puts "Target: 70 => Multiplier: #{DiceGame.new.calculate_payout_multiplier(70).round(2)}"
puts "Target: 90 => Multiplier: #{DiceGame.new.calculate_payout_multiplier(90).round(2)}"
puts "Target: 99 => Multiplier: #{DiceGame.new.calculate_payout_multiplier(99).round(2)}"

# Sinatra routes
game = DiceGame.new

get '/' do
  erb :index, locals: { 
    server_seed_hash: game.get_server_seed_hash, 
    result: nil, 
    verification_result: nil, 
    email: params[:email],
    target_number_val: '', # For form pre-fill
    bet_amount_val: '',     # For form pre-fill
    game: game
  }
end

post '/verify_email' do
  email = params[:email]
  # Basic email validation
  if email && email.match?(URI::MailTo::EMAIL_REGEXP)
    # Add user to DB if not exists, or update (though no update needed here yet beyond nonce)
    DB.execute("INSERT OR IGNORE INTO users (email, last_nonce) VALUES (?, 0)", email)
    # In a real app, send a verification email here.
    # For this example, we'll just confirm registration.
    erb :index, locals: { 
      server_seed_hash: game.get_server_seed_hash, 
      email: email, 
      email_verified: true, 
      message: "Email '#{email}' registered. You can now play.",
      target_number_val: '', # Keep form fields consistent
      bet_amount_val: '',     # Keep form fields consistent
      game: game
    }
  else
    erb :index, locals: { 
      server_seed_hash: game.get_server_seed_hash, 
      error: "Invalid email format.", 
      result: nil, 
      verification_result: nil,
      target_number_val: '', # Keep form fields consistent
      bet_amount_val: '',     # Keep form fields consistent
      game: game
    }
  end
end

post '/play' do
  email = params[:email]
  # Corrected client_seed logic: generate if nil or empty string
  client_seed = (params[:client_seed].nil? || params[:client_seed].empty?) ? SecureRandom.hex(32) : params[:client_seed]
  
  target_number_str = params[:target_number]
  bet_amount_str = params[:bet_amount]

  # Basic validation for presence before conversion
  if target_number_str.nil? || target_number_str.empty? || bet_amount_str.nil? || bet_amount_str.empty?
    return erb :index, locals: {
      server_seed_hash: game.get_server_seed_hash,
      error: "Target number and Bet amount are required.",
      result: nil, verification_result: nil, email: email,
      client_seed: client_seed,
      target_number_val: target_number_str || '', # Repopulate form
      bet_amount_val: bet_amount_str || ''       # Repopulate form
    }
  end

  target_number = target_number_str.to_i
  bet_amount = bet_amount_str.to_f # Allow fractional bet amounts

  begin
    # Ensure email is provided for play
    raise "Email is required to play." if email.nil? || email.empty?

    result = game.play(email, client_seed, target_number, bet_amount) # Use new parameters

    erb :index, locals: {
      server_seed_hash: game.get_server_seed_hash,
      result: result, # result now contains payout, target_number, bet_amount
      verification_result: nil,
      client_seed: client_seed, # For display/repopulation
      email: email,
      target_number_val: result[:target_number].to_s,
      bet_amount_val: result[:bet_amount].to_s,
      game: game # Pass game object to view for dynamic edge display
    }
  rescue StandardError => e
    erb :index, locals: { 
        server_seed_hash: game.get_server_seed_hash, 
        error: e.message, 
        result: nil, 
        verification_result: nil, 
        email: email,
        client_seed: client_seed,
        target_number_val: target_number_str, # Repopulate with original input on error
        bet_amount_val: bet_amount_str        # Repopulate with original input on error
    }
  end
end

post '/verify' do
  server_seed = params[:server_seed]
  client_seed = params[:client_seed]
  bet = params[:bet].to_i
  nonce = params[:nonce].to_i
  expected_number = params[:expected_number].to_i

  begin
    is_valid = game.verify(server_seed, client_seed, bet, nonce, expected_number)
    # Re-play the game with the *revealed* server_seed to show the number for verification display
    # This assumes the user wants to see the number that was generated with the revealed seed.
    # Note: The original game instance `game` has its @server_seed changed after each play if we don't re-initialize.
    # For simplicity in this web UI, we'll use a temporary game instance for verification display if needed,
    # or ensure the main `game` object's state is managed if it were a more complex app.
    # However, the verify method itself is stateless with regards to the instance.
    
    # To show the result of the verified game round:
    # We need to ensure we are using the *exact* parameters of the game round we are verifying.
    # The `verify` method itself is fine. The challenge is displaying the "random_number" from that specific round.
    # One way is to re-calculate it, which `verify` does internally.
    # For the UI, we might want to display this number.
    
    # Let's display the verification status and the inputs.
    # The `result` from the initial play should be passed through if we want to display its details too.
    # For now, just the verification status.
    erb :index, locals: {
      server_seed_hash: game.get_server_seed_hash, # This will be the *new* hash if a game was just played
      verification_result: is_valid,
      verified_params: params, # Pass back params for display
      email: params[:email_hidden_for_verify], # Attempt to preserve email
      target_number_val: params[:bet] || '', # params[:bet] is target_number for verify form
      bet_amount_val: '', # Bet amount not directly part of verify logic, but keep consistent
      game: game
    }
  rescue StandardError => e
    erb :index, locals: { 
      server_seed_hash: game.get_server_seed_hash, 
      error: e.message, 
      result: nil, 
      verification_result: nil,
      email: params[:email_hidden_for_verify], # Attempt to preserve email
      target_number_val: params[:bet] || '',
      bet_amount_val: '',
      game: game
    }
  end
end