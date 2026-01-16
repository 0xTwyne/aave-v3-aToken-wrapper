# Fuzzing Findings

## Root Cause

aToken's `_transfer` uses `rayDivCeil` (rounds UP) while `previewDeposit()` uses `mulDiv(RAY, rate, Floor)` (rounds DOWN). This causes wrapper to receive 1 wei more scaled balance than shares minted per direct aToken deposit.

**Affected**: `depositATokens()`, `depositWithPermit(..., false)`
**NOT Affected**: `deposit()`, `depositWithPermit(..., true)`

---

# INV_ATOKEN_B

## test_replay_2_depositATokens

- Status: DISABLED
- Invariant: `INV_ATOKEN_B`
- Error: `scaledBalanceOf(wrapper) + scaledBalanceOf(CV) != totalSupply`
- Details: Left: totalSupply, Right: scaledBalanceOf sum, Delta: 1 wei
- Context: Direct aToken deposits cause scaledBalanceOf to be 1 wei higher than shares minted due to rounding difference

---

# INV_ATOKEN_A

## test_replay_2_depositATokens

- Status: DISABLED
- Invariant: `INV_ATOKEN_A`
- Error: `aToken.balanceOf(wrapper) + aToken.balanceOf(CV) < totalAssets`
- Details: Left: aToken balances sum, Right: totalAssets, Delta: 1 wei
- Context: Same root cause - totalAssets derived from totalSupply which is 1 wei less than actual aToken balance

---

# INV_ERC4626_A

## test_replay_2_depositWithPermit

- Status: DISABLED
- Invariant: `INV_ERC4626_A`
- Error: `aToken balance < sum of redeemable assets`
- Details: Left: aToken balance, Right: redeemableAssetsSum, Delta: 1 wei
- Context: Same root cause - share/asset accounting mismatch from aToken deposit rounding

---

# GPOST_ERC4626_A

## test_replay_2_rebalanceATokens_CV

- Status: DISABLED
- Invariant: `GPOST_ERC4626_A`
- Error: `exchange rate decreased after operation`
- Details: \_before.exchangeRate > \_after.exchangeRate
- Context: Same root cause - totalSupply is 1 wei less than expected, affecting rate calculation

---

# GPOST_ERC4626_A

## test_replay_3_rebalanceATokens_CV

- Status: FAILING
- Invariant: `GPOST_ERC4626_A`
- Error: `exchange rate decreased after operation`
- Details: \_before.exchangeRate > \_after.exchangeRate
- Context: Same root cause - uses `depositATokens` triggering rounding mismatch

---

# INV_ATOKEN_A

## test_replay_4_rebalanceATokens_CV

- Status: FAILING
- Invariant: `INV_ATOKEN_A`
- Error: `aToken.balanceOf(wrapper) + aToken.balanceOf(CV) < totalAssets`
- Details: Left: 875, Right: 876, Delta: 1 wei
- Context: Same root cause - uses `depositATokens` triggering rounding mismatch