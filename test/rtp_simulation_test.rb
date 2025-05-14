require 'minitest/autorun'
require_relative '../app'

class RTPSimulationTest < Minitest::Test
  def setup
    @game = DiceGame.new
    @email = "simulation@test.com"
    @client_seed = "test_seed"
    DB.execute("INSERT OR REPLACE INTO users (email, last_nonce) VALUES (?, 0)", @email)
  end

  def test_rtp_simulation
    simulations = 1000  # Number of simulations for stable results
    bet_amount = 1.0   # Base bet amount
    target_numbers = [50, 70, 90]  # Testing different target numbers

    results = {}
    target_numbers.each do |target|
      total_bets = 0.0
      total_returns = 0.0
      wins = 0
      current_streak = 0
      max_win_streak = 0
      max_loss_streak = 0
      current_streak_type = nil

      simulations.times do
        result = @game.play(@email, @client_seed, target, bet_amount)
        total_bets += bet_amount
        total_returns += result[:payout]
        
        # Count wins and streaks
        if result[:win]
          wins += 1
          if current_streak_type == :win
            current_streak += 1
          else
            current_streak_type = :win
            current_streak = 1
          end
          max_win_streak = [max_win_streak, current_streak].max
        else
          if current_streak_type == :loss
            current_streak += 1
          else
            current_streak_type = :loss
            current_streak = 1
          end
          max_loss_streak = [max_loss_streak, current_streak].max
        end
      end

      rtp = (total_returns / total_bets) * 100
      win_rate = (wins.to_f / simulations) * 100

      results[target] = {
        rtp: rtp.round(2),
        win_rate: win_rate.round(2),
        theoretical_rtp: ((1 - @game.calculate_dynamic_edge(target)) * 100).round(2),
        max_win_streak: max_win_streak,
        max_loss_streak: max_loss_streak,
        expected_win_rate: target  # Theoretical win percentage equals target number
      }

      # Check if RTP is within acceptable limits (±6% from theoretical value)
      theoretical_rtp = (1 - @game.calculate_dynamic_edge(target)) * 100
      assert_in_delta theoretical_rtp, rtp, 6.0,
        "RTP for target=#{target} (#{rtp.round(2)}%) deviates from theoretical (#{theoretical_rtp.round(2)}%)"
      
      # Check minimum RTP (usually 80-90% for iGaming)
      assert rtp >= 80.0, "RTP for target=#{target} (#{rtp.round(2)}%) is below minimum allowed value of 80%"
    end

    # Print simulation results
    puts "\nMonte Carlo Simulation Results (#{simulations} games for each target):"
    puts "============================================================"
    results.each do |target, data|
      puts "Target Number: #{target}"
      puts "  Actual RTP: #{data[:rtp]}%"
      puts "  Theoretical RTP: #{data[:theoretical_rtp]}%"
      puts "  Win Rate: #{data[:win_rate]}% (expected: #{data[:expected_win_rate]}%)"
      puts "  Maximum Win Streak: #{data[:max_win_streak]}"
      puts "  Maximum Loss Streak: #{data[:max_loss_streak]}"
      puts "------------------------------------------------------------"
    end
  end

  def test_variance_analysis
    target_number = 50
    simulations = 100
    session_length = 10  # Number of games in one session
    bet_amount = 1.0

    session_results = []
    simulations.times do
      session_balance = 0.0
      session_length.times do
        result = @game.play(@email, @client_seed, target_number, bet_amount)
        session_balance += (result[:payout] - bet_amount)
      end
      session_results << session_balance
    end

    # Calculate volatility statistics
    mean = session_results.sum / simulations
    variance = session_results.map { |x| (x - mean) ** 2 }.sum / simulations
    std_dev = Math.sqrt(variance)
    
    # Calculate ruin rate (percentage of sessions with negative balance)
    ruin_rate = session_results.count { |x| x < 0 }.to_f / simulations * 100

    puts "\nVolatility Analysis (#{simulations} sessions of #{session_length} games):"
    puts "============================================================"
    puts "Target Number: #{target_number}"
    puts "Average Session Balance: #{mean.round(2)}"
    puts "Standard Deviation: #{std_dev.round(2)}"
    puts "Ruin Rate: #{ruin_rate.round(2)}%"
    puts "Min Balance: #{session_results.min.round(2)}"
    puts "Max Balance: #{session_results.max.round(2)}"

    # Check if ruin rate is within reasonable limits
    assert ruin_rate < 70.0, "Ruin rate too high: #{ruin_rate.round(2)}%"
  end
end
