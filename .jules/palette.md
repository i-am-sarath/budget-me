IconButtons in Flutter do not provide accessibility labels by default. To make them accessible to screen readers, they must be explicitly wrapped in a `Semantics(label: '...', button: true, child: ...)` widget and should define the `tooltip` property to provide hover/long-press context.

I applied this pattern across several screens (Dashboard, History, Subscriptions, Recurring).
