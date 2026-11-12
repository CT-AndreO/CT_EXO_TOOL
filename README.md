# EXO Tool 

A lightweight, modular PowerShell utility designed to simplify administrative management of Exchange Online (EXO). Handles automatic module validation, multi-tenant switching, single-mailbox archiving, auto-expansion, real-time storage monitoring, calendar delegation, and high-performance bulk operations/reporting.

---

### Running the Program

Simply double-click `Run.bat` to launch.
- Automatically selects PowerShell 7 (`pwsh`) if installed, or falls back to Windows PowerShell 5.1.
- Automatically bypasses execution policies without requiring permanent changes to local machine policies.

---

### Architecture & Project Structure

```
CT_EXO_TOOL/
├── Main.ps1                    # Main application router and session controller
├── Run.bat                     # Quick launcher with execution policy bypass
├── README.md                   # Project documentation
└── Functions/
    ├── Startup/
    │   ├── DependencyCheck.ps1 # Validates PowerShell environment and ExchangeOnlineManagement module
    │   ├── Search.ps1          # Ambiguous name resolution and prefix mailbox lookup
    │   ├── SignIn.ps1          # Authenticates to Exchange Online and captures tenant context
    │   └── Switch.ps1          # Cleanly switches tenants and purges cross-tenant state
    │
    ├── Mailbox/
    │   ├── 0_UserHub.ps1       # Single-user action router and metadata display
    │   ├── 1_ManageArchive.ps1 # Online archive toggle, MRM retention tags, and Managed Folder Assistant
    │   ├── 2_ManageExpansion.ps1# Auto-expanding archive limit controls and status
    │   ├── 3_StorageMonitor.ps1# Live quota and usage analytics monitor with non-blocking refresh
    │   ├── 4_CalendarSharing.ps1# Bidirectional calendar delegation and permission management
    │   ├── 5_FolderStatistics.ps1# Detailed folder item counts and size statistics
    │   └── Utils/
    │       └── Helpers.ps1     # Byte parsing, quota formatters, and regional calendar path resolver
    │
    ├── Bulk/
    │   ├── BulkOperations.ps1  # Interactive matrix UI for multi-mailbox auditing, storage, and delegation
    │   └── ExportReport.ps1    # Dedicated CSV export engine for mailbox metrics
    │
    └── Audit/
        └── AuditLog.ps1        # Unified Audit Log search, date range validator, pagination, and CSV export
```

---

### Program Menu & Option Breakdown

#### Main Menu
- **1. Single Mailbox Management**: Search and select any mailbox by Name, Email, or UPN.
- **2. Bulk Operations & Reporting Matrix**: Audit, filter, and modify multiple mailboxes across storage and delegation views.
- **3. Exchange Online Event Audit Log**: Audit events via `Search-UnifiedAuditLog` across specific dates, date ranges, or presets with pagination, JSON detail view, and CSV export.
- **4. Switch Tenant / Sign Out**: Change organizational context with full memory cache purging to prevent cross-tenant data leakage.
- **0. Exit**: Disconnect active sessions and close the application.

#### Single Mailbox Hub (`Option 1`)
- **1. Archiving & Retention Policies**: View archive state, inspect Move-to-Archive tags, assign retention policies, and trigger the Managed Folder Assistant (`Start-ManagedFolderAssistant`).
- **2. Auto-Expanding Archive Management**: View auto-expansion status and provision expanding storage (up to 1.5 TB).
- **3. Mailbox Storage & Analytics (Live Monitor)**: Real-time telemetry dashboard showing primary and archive usage, item counts, quota limits (including Unlimited), and session deltas with non-blocking hotkeys (`R` to refresh, `B`/`0` to return).
- **4. Calendar Sharing & Permissions Delegation**: View permissions, grant/update delegates on this user's calendar, revoke delegates, inspect inbound shared calendars, or bulk delegate other calendars.
- **5. Folder Statistics & Item Counts**: Breakdown of all mailbox folders, item counts, sizes, online archive folders, and CSV export.
- **0. Return to User Search**: Back to lookup prompt.

#### Bulk Operations & Reporting (`Option 2`)
An interactive matrix workspace featuring high-performance collection processing:
- **Navigation & Views (`[V1]`, `[V2]`)**: Toggle between Storage Analytics View and Delegation Matrix View.
- **Selection (`[#]`, `[A]`, `[D]`)**: Toggle selection for individual IDs (or comma-separated lists), select all, or clear choices.
- **Rules & Filters (`[T]`, `[L]`, `[F]`)**: Configure storage utilization thresholds, toggle license guardrail filters, and auto-select mailboxes exceeding thresholds.
- **Storage Actions (`[MODE]`, `[STOR1]`, `[STOR2]`, `[STOR3]`)**: Bulk enable/disable online archives, provision auto-expansion, or apply both in tandem.
- **Delegation Actions (`[MODE]`, `[SEND1]`, `[SEND2]`, `[SEND3]`, `[APPLY]`)**: Bulk grant or remove `FullAccess`, `SendAs`, or `SendOnBehalfTo` permissions for a target delegate across selected mailboxes.
- **Reporting & Cache (`[E]`, `[R]`)**: Export loaded metrics to UTF-8 CSV via `ExportReport.ps1`, or force-flush and rescan tenant metrics.
- **0. Return to Main Menu**: Go back to top-level menu.
