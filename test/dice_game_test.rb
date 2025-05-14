require 'minitest/autorun'
require_relative '../app'

class DiceGameTest < Minitest::Test
  def setup
    @game = DiceGame.new
  end

  def test_dynamic_edge_calculation
    # Test base edge for numbers <= 50
    assert_equal 0.01, @game.calculate_dynamic_edge(50)
    assert_equal 0.01, @game.calculate_dynamic_edge(1)

    # Test progressive edge increase
    assert_equal 0.05, @game.calculate_dynamic_edge(70).round(2)
    assert_equal 0.09, @game.calculate_dynamic_edge(90).round(2)
    assert_equal 0.108, @game.calculate_dynamic_edge(99).round(3)
  end

  def test_payout_multiplier_calculation
    # Test fair multipliers with house edge
    assert_in_delta 1.98, @game.calculate_payout_multiplier(50).round(2), 0.01
    assert_in_delta 1.36, @game.calculate_payout_multiplier(70).round(2), 0.01
    assert_in_delta 1.01, @game.calculate_payout_multiplier(90).round(2), 0.01
    assert_in_delta 0.90, @game.calculate_payout_multiplier(99).round(2), 0.02  # Increased delta for high target numbers
  end

  def test_game_result_win
    email = "test@example.com"
    client_seed = "test_seed"
    target_number = 50
    bet_amount = 100.0

    # Add test user to database
    DB.execute("INSERT OR REPLACE INTO users (email, last_nonce) VALUES (?, 0)", email)

    # Play game
    result = @game.play(email, client_seed, target_number, bet_amount)

    # Basic structure checks
    assert_kind_of Hash, result
    assert_includes [true, false], result[:win]
    assert_kind_of Integer, result[:number]
    assert_kind_of Integer, result[:nonce]
    assert_kind_of Float, result[:payout] if result[:win]
    assert_equal target_number, result[:target_number]
    assert_equal bet_amount, result[:bet_amount]

    # Verify number is in valid range
    assert result[:number].between?(1, 100)

    # Verify win condition matches
    assert_equal (result[:number] <= target_number), result[:win]

    # Verify payout calculation if win
    if result[:win]
      expected_payout = (bet_amount * @game.calculate_payout_multiplier(target_number)).round(2)
      assert_equal expected_payout, result[:payout]
    else
      assert_equal 0.0, result[:payout]
    end
  end

  def test_invalid_inputs
    email = "test@example.com"
    client_seed = "test_seed"
    DB.execute("INSERT OR REPLACE INTO users (email, last_nonce) VALUES (?, 0)", email)

    # Test invalid target number below range
    assert_raises(RuntimeError) do
      @game.play(email, client_seed, 0, 100.0)
    end

    # Test invalid target number above range
    assert_raises(RuntimeError) do
      @game.play(email, client_seed, 100, 100.0)
    end

    # Test invalid bet amount
    assert_raises(RuntimeError) do
      @game.play(email, client_seed, 50, -100.0)
    end

    # Test invalid email
    assert_raises(RuntimeError) do
      @game.play("nonexistent@email.com", client_seed, 50, 100.0)
    end
  end

  def test_result_verification
    email = "test@example.com"
    client_seed = "test_seed"
    DB.execute("INSERT OR REPLACE INTO users (email, last_nonce) VALUES (?, 0)", email)
    
    # Play a game first
    result = @game.play(email, client_seed, 50, 100.0)
    
    # Verify the result
    assert @game.verify(
      result[:server_seed],
      client_seed,
      result[:target_number],
      result[:nonce],
      result[:number]
    )
  end

  def test_nonce_increment
    email = "test@example.com"
    client_seed = "test_seed"
    DB.execute("INSERT OR REPLACE INTO users (email, last_nonce) VALUES (?, 0)", email)
    
    # Play multiple games and verify nonce increments
    result1 = @game.play(email, client_seed, 50, 100.0)
    result2 = @game.play(email, client_seed, 50, 100.0)
    
    assert_equal 1, result1[:nonce]
    assert_equal 2, result2[:nonce]
  end
end
