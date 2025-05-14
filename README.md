# 🎲 Dice Game - Provably Fair Casino Game

A web-based dice game implementation with provably fair gaming mechanics, dynamic house edge, and real-time result verification.

## 🎯 Features

- **Provably Fair Gaming**
  - Server seed + client seed + nonce mechanism
  - Complete transparency in number generation
  - Ability to verify every game result
  
- **Dynamic House Edge**
  - Base house edge: 1% for target numbers ≤ 50
  - Progressive increase for higher target numbers:
    - Target 50: 1% house edge (~1.98× multiplier)
    - Target 70: 5% house edge (~1.36× multiplier)
    - Target 90: 9% house edge (~1.01× multiplier)
    - Target 99: 10.8% house edge (~0.89× multiplier)

- **User Management**
  - Email-based registration
  - Persistent nonce tracking per user
  
- **Real-time Gaming**
  - Instant win/loss results
  - Dynamic payout calculations
  - Displayed house edge and multipliers

## 🛠 Tech Stack

- Ruby 3.x
- Sinatra web framework
- SQLite3 database
- Cryptographic functions (SHA-256, SHA-512)

## 📋 Prerequisites

- Ruby 3.x
- Bundler

## 🚀 Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd dice_game
```

2. Install dependencies:
```bash
bundle install
```

## 🎮 Running the Game

1. Start the server:
```bash
ruby app.rb
```

2. Open in browser:
```
http://localhost:4567
```

## 🎲 How to Play

1. Register with your email
2. Choose your target number (1-99)
3. Enter bet amount
4. Optionally provide your own client seed
5. Click "Play" to roll
6. Verify the result using provided seeds and nonce

## 🔍 Verification Process

Each game result can be verified:
1. Server seed is revealed after the game
2. Combine: `server_seed:client_seed:nonce`
3. Generate SHA-512 hash
4. Convert to number 1-100
5. Compare with the provided result

## 🛡 Security Features

- Server seed hash shown before play
- Complete seed revealed after play
- Nonce tracking per user
- Cryptographic grade randomness
- All parameters available for verification

## 📊 House Edge Calculation

```ruby
def calculate_dynamic_edge(target_number)
  base_edge = 0.01  # 1% base
  extra_edge = [(target_number - 50) * 0.002, 0].max
  base_edge + extra_edge
end
```

## 💻 Development

- The game uses Sinatra for a lightweight web framework
- SQLite3 for simple but effective user storage
- Clear separation of game logic and web interface
- Comprehensive error handling
- Mobile-friendly UI

## 🔒 License

MIT License - feel free to use and modify
