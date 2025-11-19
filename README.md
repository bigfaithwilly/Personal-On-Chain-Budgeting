# 💰 Personal On-Chain Budgeting

A decentralized budgeting application built on the Stacks blockchain using Clarity smart contracts. Track your spending, set category limits, and manage your finances on-chain! 📊

## 🌟 Features

- 📝 **Create Multiple Budgets**: Set up different budgets with custom names and total limits
- 🏷️ **Category Management**: Organize expenses into categories with individual spending limits
- 💸 **Expense Tracking**: Record expenses with descriptions and automatic budget validation
- 🔄 **Automatic Reset Cycles**: Choose from weekly, monthly, quarterly, or yearly reset periods
- 📈 **Real-time Monitoring**: Check budget status, remaining amounts, and spending percentages
- ⏰ **Time-based Resets**: Automatic budget reset based on configurable periods

## 🚀 Quick Start

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Basic knowledge of Clarity smart contracts

### Installation

1. Clone the repository:
```bash
git clone https://github.com/your-username/Personal-On-Chain-Budgeting
cd Personal-On-Chain-Budgeting
```

2. Run Clarinet check to verify the contract:
```bash
clarinet check
```

3. Start the local development environment:
```bash
clarinet console
```

## 📚 Usage Guide

### 1. 📋 Create a Budget

Create a new budget with a name, total limit, and reset period:

```clarity
(contract-call? .Budget create-budget "Monthly Expenses" u1000000 u4)
```

**Parameters:**
- `name`: Budget name (max 50 characters)
- `total-limit`: Maximum spending amount in microSTX
- `reset-period`: Reset frequency (1=weekly, 4=monthly, 12=quarterly, 52=yearly)

### 2. 🏷️ Add Categories

Add spending categories to your budget:

```clarity
(contract-call? .Budget add-category u1 "Food" u300000)
(contract-call? .Budget add-category u1 "Transport" u150000)
(contract-call? .Budget add-category u1 "Entertainment" u100000)
```

**Parameters:**
- `budget-id`: ID of the budget (returned from create-budget)
- `category`: Category name (max 30 characters)
- `limit`: Maximum spending for this category

### 3. 💳 Record Expenses

Track your spending by adding expenses:

```clarity
(contract-call? .Budget add-expense u1 "Food" u50000 "Grocery shopping")
(contract-call? .Budget add-expense u1 "Transport" u25000 "Gas for car")
```

**Parameters:**
- `budget-id`: Budget ID
- `category`: Category name
- `amount`: Expense amount in microSTX
- `description`: Expense description (max 100 characters)

### 4. 📊 Monitor Your Budget

Check your budget status and remaining amounts:

```clarity
;; Get budget overview
(contract-call? .Budget get-budget-status 'SP1ABC... u1)

;; Check remaining budget
(contract-call? .Budget get-budget-remaining 'SP1ABC... u1)

;; Check category remaining
(contract-call? .Budget get-category-remaining 'SP1ABC... u1 "Food")
```

### 5. 🔄 Reset Budget

Reset your budget when the period ends:

```clarity
(contract-call? .Budget reset-budget u1)
```

## 🔧 Advanced Features

### Budget Management

- **Deactivate Budget**: Temporarily disable a budget
```clarity
(contract-call? .Budget deactivate-budget u1)
```

- **Activate Budget**: Re-enable a deactivated budget
```clarity
(contract-call? .Budget activate-budget u1)
```

- **Update Category Limits**: Modify spending limits for categories
```clarity
(contract-call? .Budget update-category-limit u1 "Food" u400000)
```

### Data Queries

- **Get Budget Details**:
```clarity
(contract-call? .Budget get-budget 'SP1ABC... u1)
```

- **Get Category Info**:
```clarity
(contract-call? .Budget get-category 'SP1ABC... u1 "Food")
```

- **Get Expense Record**:
```clarity
(contract-call? .Budget get-expense 'SP1ABC... u1)
```

- **Check Reset Status**:
```clarity
(contract-call? .Budget needs-reset 'SP1ABC... u1)
```

## 📖 Data Structures

### Budget Structure
```clarity
{
  name: (string-ascii 50),           ;; Budget name
  total-limit: uint,                 ;; Total spending limit
  current-spent: uint,               ;; Current spent amount
  reset-period: uint,                ;; Reset period in blocks
  last-reset: uint,                  ;; Last reset block height
  active: bool                       ;; Budget status
}
```

### Category Structure
```clarity
{
  limit: uint,                       ;; Category spending limit
  spent: uint,                       ;; Amount spent in category
  active: bool                       ;; Category status
}
```

### Expense Structure
```clarity
{
  budget-id: uint,                   ;; Associated budget ID
  category: (string-ascii 30),       ;; Expense category
  amount: uint,                      ;; Expense amount
  description: (string-ascii 100),   ;; Expense description
  timestamp: uint                    ;; Block height when created
}
```

## 🔒 Security Features

- ✅ Only budget owners can modify their budgets
- ✅ Automatic validation of spending limits
- ✅ Prevention of overspending beyond category/budget limits
- ✅ Immutable expense records once created
- ✅ Time-based reset protection

## 📄 Error Codes

- `u100`: Unauthorized access
- `u101`: Budget not found
- `u102`: Category already exists
- `u103`: Insufficient budget remaining
- `u104`: Invalid amount (must be greater than 0)
- `u105`: Invalid reset period

## 🛠️ Development

### Running Tests

```bash
clarinet test
```

### Deploying

```bash
clarinet deploy --testnet
```

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built on [Stacks Blockchain](https://stacks.co/)
- Developed with [Clarity](https://clarity-lang.org/)
- Powered by [Clarinet](https://github.com/hirosystems/clarinet)

---

Made with ❤️ for the Stacks community 🚀
