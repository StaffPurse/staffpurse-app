> ## Documentation Index
> Fetch the complete documentation index at: https://bkey.mintlify.site/llms.txt
> Use this file to discover all available pages before exploring further.

# Widgets

> EmbeddedWalletCard and EmbeddedWalletTransactionsSection.

## EmbeddedWalletCard

A model-aware card widget. Takes an `EmbeddedWallet` and renders the correct background art, currency-formatted balance, and optional info button — all wired to the `bkey_uikit` `BMoniWalletCard` primitive under the hood.

```dart theme={null}
EmbeddedWalletCard(
  wallet: embeddedWallet,
  isBalanceHidden: hiddenBalances.contains(embeddedWallet.walletId),
  onToggleHideBalance: () => toggleHidden(embeddedWallet.walletId),
  isLoading: isInitialLoad,
  isRefreshing: isPullToRefreshing,
  onInfoTap: () => openWalletDetails(embeddedWallet),
  onTap: () => openWalletDetails(embeddedWallet),
)
```

### Props

| Prop                  | Type                       | Default | Description                                                                                                      |
| --------------------- | -------------------------- | ------- | ---------------------------------------------------------------------------------------------------------------- |
| `wallet`              | `EmbeddedWallet`           | —       | The wallet model to render.                                                                                      |
| `isBalanceHidden`     | `bool`                     | `false` | When `true`, replaces the balance with bullet dots.                                                              |
| `onToggleHideBalance` | `VoidCallback`             | —       | Called when the eye icon is tapped.                                                                              |
| `isLoading`           | `bool`                     | `false` | Shows a skeleton / placeholder while the initial list loads.                                                     |
| `isRefreshing`        | `bool`                     | `false` | Shows a subtle refresh indicator during pull-to-refresh.                                                         |
| `onInfoTap`           | `VoidCallback?`            | `null`  | Called when the info button is tapped.                                                                           |
| `onTap`               | `VoidCallback?`            | `null`  | Called when the card body is tapped.                                                                             |
| `colorSuffix`         | `String?`                  | `null`  | Pick a colour variant `'01'`–`'06'` for branded background art. Omit to use the default per-currency background. |
| `currencySymbol`      | `String?`                  | `null`  | Override the prefix shown before the balance (e.g. `r'$'`).                                                      |
| `formatWholePart`     | `String Function(double)?` | `null`  | Override the whole-part formatting entirely.                                                                     |

### Carousel layout

The card is designed for a `PageView`:

```dart theme={null}
SizedBox(
  height: 270,
  child: PageView.builder(
    controller: PageController(viewportFraction: 0.92),
    itemCount: wallets.length,
    onPageChanged: (index) => setState(() => _selected = wallets[index]),
    itemBuilder: (context, index) {
      final wallet = wallets[index];
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: EmbeddedWalletCard(
          wallet: wallet.copyWith(
            balance: balances[wallet.walletId] ?? wallet.balance,
          ),
          isBalanceHidden: hidden.contains(wallet.walletId),
          onToggleHideBalance: () => toggleHidden(wallet.walletId),
          isLoading: listState.isLoading,
          isRefreshing: listState.isRefreshing,
          onTap: () => setState(() => _selected = wallet),
          onInfoTap: () => showWalletInfo(wallet),
        ),
      );
    },
  ),
)
```

***

## EmbeddedWalletTransactionsSection

A section widget that wraps a list of `EmbeddedWalletTransaction` items. It handles loading, empty, and populated states; the host app provides the item builder and the empty state.

```dart theme={null}
EmbeddedWalletTransactionsSection(
  title: '${activeWallet.name} activity',
  viewAllLabel: 'View all',
  onViewAll: () => navigateToHistory(),
  transactions: transactions,
  isInitialLoading: txState.isLoading && transactions.isEmpty,
  emptyState: const EmptyTransactionsWidget(),
  itemBuilder: (context, transaction) => TransactionTile(
    transaction: transaction,
  ),
)
```

### Props

| Prop               | Type                                                       | Default | Description                                                |
| ------------------ | ---------------------------------------------------------- | ------- | ---------------------------------------------------------- |
| `title`            | `String`                                                   | —       | Section heading.                                           |
| `viewAllLabel`     | `String?`                                                  | `null`  | Label for the "view all" link. Hidden when `null`.         |
| `onViewAll`        | `VoidCallback?`                                            | `null`  | Called when the "view all" link is tapped.                 |
| `transactions`     | `List<EmbeddedWalletTransaction>`                          | —       | The transaction list.                                      |
| `isInitialLoading` | `bool`                                                     | `false` | When `true`, shows a loading skeleton instead of the list. |
| `emptyState`       | `Widget`                                                   | —       | Widget shown when `transactions` is empty.                 |
| `itemBuilder`      | `Widget Function(BuildContext, EmbeddedWalletTransaction)` | —       | Builder for each transaction row.                          |

### Building a transaction row

The host app is fully in control of how each row looks. A minimal example using `bkey_uikit` primitives:

```dart theme={null}
itemBuilder: (context, tx) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 8),
  child: Row(
    children: [
      Icon(
        tx.isIncoming ? Icons.south_west : Icons.north_east,
        color: tx.isIncoming
            ? context.colors.text.successDefault
            : context.colors.text.errorDefault,
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HeadingText(
              tx.title ?? tx.counterpartyName ?? 'Transaction',
              level: 6,
              weight: HeadingWeight.semibold,
            ),
            LabelText(
              tx.status.name,
              size: LabelSize.small,
              weight: LabelWeight.regular,
            ),
          ],
        ),
      ),
      Text(
        '${tx.isIncoming ? '+' : '-'}${tx.amount} ${tx.currency ?? ''}',
        style: BMoniTextStyles.h6Semibold.copyWith(
          color: tx.isIncoming
              ? context.colors.text.successDefault
              : context.colors.text.errorDefault,
        ),
      ),
    ],
  ),
),
```
