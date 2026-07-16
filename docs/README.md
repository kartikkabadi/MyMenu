# MyMonitor Specifications

MyMonitor has two canonical implementation contracts:

1. [`frontend/`](frontend/README.md) defines the native macOS surfaces, interaction, accessibility, visual system, and frontend/backend boundary.
2. [`backend/`](backend/README.md) defines the local display-control engine, lifecycle, durable identity, control methods, diagnostics, migration, and hardware qualification.

Product work must preserve both contracts. A pull request that changes user-visible brightness semantics, display state, recovery, control-method reporting, Settings configuration, or diagnostics normally affects both programmes and must update the relevant documents together.

The contracts deliberately keep the product narrow: a native menu-bar utility for external-monitor brightness, with no generic utility suite, account system, analytics, cloud service, or unrelated display-management surface.