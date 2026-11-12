# EXO Tool - Microsoft Exchange Online Administration Utility

A lightweight, enterprise-ready, modular PowerShell management suite designed for Microsoft 365 / Exchange Online (EXO) administrators, IT engineers, and MSPs. **EXO Tool** streamlines routine administration tasks, reporting, mailbox storage optimization, calendar delegation, and security auditing across single or multiple tenants.

---

## Table of Contents

- [Key Capabilities](#key-capabilities)
- [System Requirements & Prerequisites](#system-requirements--prerequisites)
- [Quick Start / How to Run](#quick-start--how-to-run)
- [Architecture & Repository Structure](#architecture--repository-structure)
- [Detailed Module Documentation](#detailed-module-documentation)
  - [Root Controller & Launchers](#root-controller--launchers)
  - [Startup & Authentication (`Functions/Startup/`)](#startup--authentication-functionsstartup)
  - [Single Mailbox Management (`Functions/Mailbox/`)](#single-mailbox-management-functionsmailbox)
  - [Bulk Management & Reporting (`Functions/Bulk/`)](#bulk-management--reporting-functionsbulk)
  - [Audit & Compliance (`Functions/Audit/`)](#audit--compliance-functionsaudit)
  - [Shared Utilities (`Functions/Mailbox/Utils/`)](#shared-utilities-functionsmailboxutils)
- [Menu Navigation & Workflow Guide](#menu-navigation--workflow-guide)
- [Design Principles, Safety & Error Handling](#design-principles-safety--error-handling)
- [Troubleshooting & FAQ](#troubleshooting--faq)

---

## Key Capabilities

- **Automatic Prerequisites & Authentication**: Automatically detects environment requirements, checks/installs the `ExchangeOnlineManagement` module, and connects with interactive MFA.
- **Tenant Isolation & Multi-Tenant Support**: Displays active organization context in all headers and cleanly wipes session caches during tenant switches to eliminate cross-tenant data contamination.
- **Granular Single Mailbox Management**:
  - Enable/disable Online Archiving with user confirmation safeguards.
  - Inspect MRM retention policies and Move-to-Archive tags.
  - Trigger immediate backend processing via `Start-ManagedFolderAssistant`.
  - Provision Auto-Expanding Archive storage (up to 1.5 TB).
  - Real-time telemetry storage dashboard with non-blocking hotkey refresh and accurate "Unlimited" quota calculations.
  - Bidirectional calendar permissions (inspect delegates, grant/modify access, revoke permissions, bulk delegate other calendars to user).
  - Folder item analytics with non-empty filtering and CSV exports.
- **High-Performance Bulk Operations**:
  - In-memory collection architecture (`List[PSCustomObject]`) for fast processing of tenant directories.
  - Interactive matrix console with dual views (Storage Analytics View and Delegation Matrix View).
  - Configurable storage threshold filtering and licensing guardrails.
  - Bulk online archive toggling, auto-expansion provisioning, or dual deployment.
  - Bulk permission provisioning (`FullAccess`, `SendAs`, `SendOnBehalfTo`).
  - One-click UTF-8 CSV exports with Excel compatibility.
- **Unified Audit Log (UAL) Search Engine**:
  - Flexible event auditing across single days, date ranges, or quick presets (*Today*, *Last 24 Hours*, *Last 7 Days*).
  - Strict input validation preventing out-of-bounds or future dates.
  - Granular filters by User/UPN, Operation, or RecordType.
  - Paginated console results viewer with JSON detail inspector and CSV export.

---

## System Requirements & Prerequisites

| Requirement | Supported Version | Notes |
| :--- | :--- | :--- |
| **Operating System** | Windows 10 / 11, Windows Server 2016+ | Standard PowerShell host environment |
| **PowerShell** | PowerShell 7+ (`pwsh`) or Windows PowerShell 5.1 | `Run.bat` automatically selects PowerShell 7 if present, falling back to 5.1 |
| **PowerShell Module** | `ExchangeOnlineManagement` (v3.0+) | Auto-checked and installable on launch via `DependencyCheck.ps1` |
| **Role Permissions** | Exchange Administrator / Global Reader / View-Only Audit Logs | Required to query directory data and audit logs |

---

## Quick Start / How to Run

1. Clone or download the repository to your workstation (e.g. `C:\Dev\EXO_AI_DEV\CT_EXO_TOOL`).
2. Double-click **`Run.bat`**.
   - `Run.bat` executes `Main.ps1` with `-ExecutionPolicy Bypass -NoProfile`.
   - If modern PowerShell 7 (`pwsh`) is in your system `PATH`, it runs in `pwsh` for maximum speed; otherwise, it seamlessly runs in Windows PowerShell 5.1.
3. If the `ExchangeOnlineManagement` module is missing, the tool prompts to install it automatically for `CurrentUser`.
4. Sign in via your Microsoft 365 prompt (supports Modern Authentication, FIDO2, and Conditional Access MFA).

---

## Architecture & Repository Structure

```
CT_EXO_TOOL/
├── Main.ps1                           # Core router, dependency orchestration, and main menu loop
├── Run.bat                            # Bypasses execution policy and launches pwsh/powershell
├── README.md                          # Comprehensive tool documentation
└── Functions/
    ├── Startup/
    │   ├── DependencyCheck.ps1        # Validates PS version and module availability
    │   ├── SignIn.ps1                 # Connects to Exchange Online and extracts tenant context
    │   ├── Switch.ps1                 # Disconnects, clears memory caches, and handles tenant changes
    │   └── Search.ps1                 # Ambiguous Name Resolution (ANR) and mailbox search
    │
    ├── Mailbox/
    │   ├── 0_UserHub.ps1              # Single-user menu router and mailbox metadata card
    │   ├── 1_ManageArchive.ps1        # Online archive toggle, MRM policies, and MFA trigger
    │   ├── 2_ManageExpansion.ps1      # Auto-expanding archive enablement and architecture checks
    │   ├── 3_StorageMonitor.ps1       # Real-time interactive storage usage and quota dashboard
    │   ├── 4_CalendarSharing.ps1      # Inbound/outbound calendar permissions and delegation engine
    │   ├── 5_FolderStatistics.ps1     # Mailbox/archive folder item counts, sizes, and CSV reporting
    │   └── Utils/
    │       └── Helpers.ps1            # Shared byte parsing, quota formatting, and calendar resolvers
    │
    ├── Bulk/
    │   ├── BulkOperations.ps1         # Interactive matrix UI for multi-mailbox auditing and actions
    │   └── ExportReport.ps1           # Dedicated CSV export engine for tenant mailbox audit data
    │
    └── Audit/
        └── AuditLog.ps1               # Unified Audit Log search, date range validator, pagination, and CSV export
```

---

## Detailed Module Documentation

### Root Controller & Launchers

#### [Run.bat](file:///c:/Dev/EXO_AI_DEV/CT_EXO_TOOL/Run.bat)
- **Role**: Convenience bootstrapper.
- **How It Works**: Tests for the availability of `pwsh.exe` via `where pwsh`. If detected, launches `Main.ps1` using PowerShell 7; otherwise launches `powershell.exe`. Both paths bypass execution policy restrictions for the current process session without altering system-wide execution policies.

#### [Main.ps1](file:///c:/Dev/EXO_AI_DEV/CT_EXO_TOOL/Main.ps1)
- **Role**: Top-level application coordinator and state holder.
- **How It Works**:
  1. Initializes global registers: `$Global:TargetUser`, `$Global:TenantName`, `$Global:CentralMailboxCache`, `$Global:ActiveView`.
  2. Dynamically recurses through all `.ps1` files in `Functions/` and dot-sources them into the session.
  3. Executes `Test-Dependencies` to ensure required modules are installed.
  4. Calls `Invoke-SignIn` and captures the tenant organization context.
  5. Enters the primary interactive loop with session connection guards preventing null-reference crashes if disconnected.
  6. On exit (`Option 0`), triggers a clean `Disconnect-ExchangeOnline` teardown.

---

### Startup & Authentication (`Functions/Startup/`)

#### [DependencyCheck.ps1](file:///c:/Dev/EXO_AI_DEV/CT_EXO_TOOL/Functions/Startup/DependencyCheck.ps1)
- **Exported Function**: `Test-Dependencies`
- **How It Works**:
  - Checks if `$PSVersionTable.PSVersion.Major` is at least 5.1.
  - Queries `Get-Module -ListAvailable -Name ExchangeOnlineManagement`.
  - If missing, displays an interactive dialog offering to install `ExchangeOnlineManagement` from the PowerShell Gallery (`PSGallery`) under `-Scope CurrentUser`.

#### [SignIn.ps1](file:///c:/Dev/EXO_AI_DEV/CT_EXO_TOOL/Functions/Startup/SignIn.ps1)
- **Exported Function**: `Invoke-SignIn`
- **How It Works**:
  - Imports the `ExchangeOnlineManagement` module.
  - Runs `Connect-ExchangeOnline -ShowBanner:$false`.
  - Determines the organization identity via `(Get-OrganizationConfig).DisplayName`. If unavailable, resolves via `Get-ConnectionInformation` UPN domain or Tenant ID.
  - Sets `$Global:TenantName` and returns `$true` upon success or `$false` with clear diagnostics upon failure.

#### [Switch.ps1](file:///c:/Dev/EXO_AI_DEV/CT_EXO_TOOL/Functions/Startup/Switch.ps1)
- **Exported Functions**: `Invoke-SwitchTenant`, `Clear-SessionState`
- **How It Works**:
  - Addresses cross-tenant memory leakage by explicitly nullifying `$Global:CentralMailboxCache`, `$Global:TargetUser`, and resetting layout state before switching.
  - Gives the user options to:
    1. Disconnect and authenticate to a new tenant immediately.
    2. Disconnect only (returns to Main Menu in `DISCONNECTED` state).
    0. Cancel and preserve the active session.

#### [Search.ps1](file:///c:/Dev/EXO_AI_DEV/CT_EXO_TOOL/Functions/Startup/Search.ps1)
- **Exported Function**: `Invoke-Search`
- **How It Works**:
  - Verifies session connectivity before querying.
  - Accepts user search terms (Name, Alias, Email, or UPN).
  - For inputs < 3 characters, executes an indexed wildcard filter (`DisplayName -like '$Query*' -or Alias -like '$Query*' -or UserPrincipalName -like '$Query*'`).
  - For inputs >= 3 characters, uses high-speed Ambiguous Name Resolution (`-Anr $Query`).
  - Caps interactive searches to 50 results to prevent memory bloat on large directories.
  - Returns a single match directly, or presents an indexed selection table for multiple matches.

---

### Single Mailbox Management (`Functions/Mailbox/`)

#### [0_UserHub.ps1](file:///c:/Dev/EXO_AI_DEV/CT_EXO_TOOL/Functions/Mailbox/0_UserHub.ps1)
- **Exported Function**: `Invoke-UserMenu`
- **How It Works**:
  - Acts as the central hub for the selected target user (`$Global:TargetUser`).
  - Displays a summary header including Display Name, UPN/Email, Mailbox Type (`UserMailbox`, `SharedMailbox`, `RoomMailbox`, `EquipmentMailbox`), and Creation Date.
  - Routes into sub-modules (Archiving, Auto-Expansion, Storage Analytics, Calendar Delegation, Folder Counts).

#### [1_ManageArchive.ps1](file:///c:/Dev/EXO_AI_DEV/CT_EXO_TOOL/Functions/Mailbox/1_ManageArchive.ps1)
- **Exported Functions**: `Invoke-ManageArchive`, `Get-ArchiveTagsFromPolicy`, `Show-RulesPaginationEngine`
- **How It Works**:
  - Evaluates current online archive status (`Enable-Mailbox -Archive` / `Disable-Mailbox -Archive`) with explicit user confirmation.
  - Inspects the assigned Messaging Records Management (MRM) Retention Policy container.
  - Resolves all policy tags linked to the container where `RetentionAction -eq "MoveToArchive"` and renders the retention age limit (e.g. `730 days`).
  - Allows reassigning retention policies from tenant-wide lists queried via `Get-RetentionPolicy`.
  - Features an on-demand trigger for `Start-ManagedFolderAssistant -Identity $Identity` to queue the mailbox for immediate backend lifecycle processing.

#### [2_ManageExpansion.ps1](file:///c:/Dev/EXO_AI_DEV/CT_EXO_TOOL/Functions/Mailbox/2_ManageExpansion.ps1)
- **Exported Function**: `Invoke-ManageExpansion`
- **How It Works**:
  - Reads `AutoExpandingArchiveEnabled` and online archive state from `Get-Mailbox`.
  - Ensures the online archive is enabled before permitting auto-expansion.
  - Allows provisioning expanding archive storage (up to 1.5 TB) via `Enable-Mailbox -Identity $Identity -AutoExpandingArchive`.
  - Implements architectural guardrails: explicitly informs the user that Microsoft 365 prohibits disabling auto-expansion once provisioned, avoiding invalid cmdlet calls.

#### [3_StorageMonitor.ps1](file:///c:/Dev/EXO_AI_DEV/CT_EXO_TOOL/Functions/Mailbox/3_StorageMonitor.ps1)
- **Exported Function**: `Invoke-StorageMonitor`
- **How It Works**:
  - Real-time telemetry monitor combining `Get-Mailbox` and `Get-MailboxStatistics` (primary and archive).
  - Correctly parses `"Unlimited"` quotas using `Get-RawBytes`, preventing `0 MB / 0 MB (0%)` calculation bugs.
  - Calculates real-time usage, item counts, quota limits, and percentage utilization.
  - Tracks session deltas (net MB moved/added during the monitoring session).
  - Employs a non-blocking 10-second polling cycle that listens for hotkeys (`[R]` to force immediate refresh, `[B]` or `[0]` to exit) without locking the console or triggering Exchange API throttling.

#### [4_CalendarSharing.ps1](file:///c:/Dev/EXO_AI_DEV/CT_EXO_TOOL/Functions/Mailbox/4_CalendarSharing.ps1)
- **Exported Functions**: `Invoke-CalendarSharing`, `Show-CalendarPermissions`, `Add-CalendarDelegate`, `Remove-CalendarDelegate`, `Show-InboundDelegations`, `Add-BulkCalendarPermissions`
- **How It Works**:
  - Dynamically resolves regional calendar folder names (`Kalender`, `Calendrier`, `Agenda`) via `Get-CalendarFolderPath` rather than hardcoding `:\Calendar`.
  - **Outbound Delegation**: Inspects permissions assigned to the target user's calendar (`Get-MailboxFolderPermission`).
  - **Grant Delegate Access**: Assigns roles (`AvailabilityOnly`, `LimitedDetails`, `Reviewer`, `Author`, `Editor`, `Owner`) using `Add-MailboxFolderPermission` with fallback to `Set-MailboxFolderPermission`.
  - **Revoke Delegate Access**: Lists active non-default delegates and removes them safely via `Remove-MailboxFolderPermission -Confirm:$false`.
  - **Inbound Discovery**: Allows targeted single-mailbox audits or throttled tenant-wide scans to see which external calendars the target user has access to.
  - **Bulk Outbound Assignment**: Allows multi-selecting tenant mailboxes to grant the target user access across multiple calendars in one batch.

#### [5_FolderStatistics.ps1](file:///c:/Dev/EXO_AI_DEV/CT_EXO_TOOL/Functions/Mailbox/5_FolderStatistics.ps1)
- **Exported Functions**: `Invoke-FolderStatistics`, `Show-FolderStatsTable`, `Export-FolderStatsToCsv`
- **How It Works**:
  - Queries `Get-MailboxFolderStatistics -Identity $Identity`.
  - Summarizes total mailbox folder count and total aggregated item count across all folders.
  - Views non-empty folders sorted by item count descending, or full folder trees.
  - Supports auditing online archive folder statistics (`-Archive`).
  - Exports folder statistics (`FolderPath`, `ItemsInFolder`, `DeletedItemsInFolder`, `FolderSize`, `FolderAndSubfolderSize`) to a timestamped CSV.

---

### Bulk Management & Reporting (`Functions/Bulk/`)

#### [BulkOperations.ps1](file:///c:/Dev/EXO_AI_DEV/CT_EXO_TOOL/Functions/Bulk/BulkOperations.ps1)
- **Exported Functions**: `Invoke-BulkMenu`, `Invoke-InteractiveMatrixAuditor`
- **How It Works**:
  - **High-Speed Cache**: Loads tenant user and shared mailboxes into a typed `List[PSCustomObject]` (`$Global:CentralMailboxCache`).
  - **Dual Matrix Views**:
    - `[V1]` **Storage View**: Displays Primary Utilization, Online Archive Utilization, Quotas, and Auto-Expansion flags.
    - `[V2]` **Delegation View**: Displays User Principal Names and assigned Retention Policies.
  - **Flexible Targeting**: Toggle items by ID (`[#]`, e.g. `1` or `1,3,5`), select all (`[A]`), clear choices (`[D]`), or auto-select (`[F]`) mailboxes exceeding configured capacity thresholds.
  - **Storage Actions**:
    - `[MODE]` Toggle action state (`Enable` vs `Disable`).
    - `[STOR1]` Bulk toggle Online Archiving.
    - `[STOR2]` Bulk provision Auto-Expanding Archives.
    - `[STOR3]` Bulk provision both Online Archive and Auto-Expansion in one job.
  - **Delegation Actions**:
    - `[MODE]` Toggle mode (`Add` vs `Remove`).
    - `[SEND1]` - `[SEND3]` Choose permission level (`SendAs`, `SendOnBehalf`, `FullAccess`).
    - `[SEND]` / `[APPLY]` Apply permissions for a specified delegate user across all selected mailboxes.
  - **Data Controls**: `[E]` exports loaded records to CSV; `[R]` purges and refreshes tenant metrics.

#### [ExportReport.ps1](file:///c:/Dev/EXO_AI_DEV/CT_EXO_TOOL/Functions/Bulk/ExportReport.ps1)
- **Exported Function**: `Export-MailboxAuditReport`
- **How It Works**:
  - Transforms raw matrix cache objects into standardized audit rows with MB/GB conversions, utilization percentages, archive states, retention policies, and licensing flags.
  - Prompts for a target directory (defaults to current folder), automatically creates target paths if missing, and writes a timestamped CSV (`EXO_MailboxAudit_yyyyMMdd_HHmmss.csv`) with UTF-8 encoding.

---

### Audit & Compliance (`Functions/Audit/`)

#### [AuditLog.ps1](file:///c:/Dev/EXO_AI_DEV/CT_EXO_TOOL/Functions/Audit/AuditLog.ps1)
- **Exported Functions**: `Invoke-AuditLogMenu`, `Read-ValidDate`, `Execute-AuditLogQuery`, `Show-AuditLogViewer`, `Show-AuditRecordDetails`, `Export-AuditRecordsToCsv`
- **How It Works**:
  - **Timeframe Selector**: Supports preset windows (*Today*, *Last 24 Hours*, *Last 7 Days*), single dates (`YYYY-MM-DD`), or custom date ranges.
  - **Strict Validation**: Validates inputs using `[DateTime]::TryParseExact`, ensures dates are not in the future, and validates that Start Date is earlier than End Date.
  - **Filters**: Allows filtering by Actor/User UPN, Operation (e.g. `MailItemsAccessed`, `SendAs`, `MoveToDeletedItems`, `Set-Mailbox`), or RecordType (`ExchangeItem`, `ExchangeAdmin`).
  - **Purview / EXO Query**: Executes `Search-UnifiedAuditLog` with structured exception handling diagnostics explaining role requirements (`View-Only Audit Logs`).
  - **Interactive Viewer**: Displays paginated results (15 records/page) with next/previous page navigation (`[N]`, `[P]`).
  - **Deep Record Inspector**: Enter any record ID `[#]` to parse and render the raw JSON `AuditData` payload into readable key-value properties.
  - **Exporting**: One-key export (`[E]`) of all query results to timestamped CSV.

---

### Shared Utilities (`Functions/Mailbox/Utils/`)

#### [Helpers.ps1](file:///c:/Dev/EXO_AI_DEV/CT_EXO_TOOL/Functions/Mailbox/Utils/Helpers.ps1)
- **Exported Functions**:
  - `Wait-Console`: Standardized, cross-platform interactive pause prompt.
  - `Write-ToggleStatus`: Color-coded console badge rendering (`[ENABLED]` in green, `[DISABLED]` in red).
  - `Get-RawBytes`: Robust byte extractor that converts raw Exchange string representations (e.g., `"45.12 GB (48,449,112,010 bytes)"`), pure digits, and safely returns `[double]::PositiveInfinity` for `"Unlimited"` quotas.
  - `Format-StorageSizeMB` / `Format-StorageSizeGB`: Formats byte counts into clean numeric MB/GB representations with native `Unlimited` handling.
  - `Get-CalendarFolderPath`: Uses `Get-MailboxFolderStatistics -FolderScope Calendar` to detect regional calendar folder names (e.g. `Kalender`, `Calendrier`) and falls back to `:\Calendar`.

---

## Menu Navigation & Workflow Guide

```
[Main Menu]
 ├── 1. Single Mailbox Management
 │    └── [User Search Prompt]
 │         └── [Mailbox Management Hub]
 │              ├── 1. Archiving & Retention Policies (MRM, MFA)
 │              ├── 2. Auto-Expanding Archive Management
 │              ├── 3. Mailbox Storage & Analytics (Live Monitor)
 │              ├── 4. Calendar Sharing & Permissions Delegation
 │              ├── 5. Folder Statistics & Item Counts
 │              └── 0. Return to User Search
 ├── 2. Bulk Operations & Reporting Matrix
 │    ├── [V1] Storage View / [V2] Delegation View
 │    ├── [#] Select / [A] Select All / [D] Clear / [F] Filter Thresholds
 │    ├── [STOR1 - STOR3] Bulk Archive & Expansion Actions
 │    ├── [SEND1 - SEND3 + APPLY] Bulk Delegation Actions
 │    └── [E] Export to CSV / [R] Refresh Cache
 ├── 3. Exchange Online Event Audit Log
 │    ├── 1. Today / 2. Last 24 Hours / 3. Last 7 Days
 │    ├── 4. Specific Date / 5. Custom Date Range
 │    └── [Results Viewer: Paging, Record Detail JSON, CSV Export]
 ├── 4. Switch Tenant / Sign Out
 └── 0. Exit
```

---

## Design Principles, Safety & Error Handling

1. **State Isolation**: Switching tenants or signing out immediately purges `$Global:CentralMailboxCache` and `$Global:TargetUser`. Operations cannot cross tenant boundaries.
2. **Explicit Confirmation on Destructive Actions**: Disabling archives, granting bulk permissions, and committing storage changes always require affirmative `(Y/N)` user confirmation.
3. **No Unhandled Crashes**: All remote Exchange Online calls are wrapped in `try/catch` blocks that output clear error diagnostics and pause via `Wait-Console` rather than dumping raw script traces or exiting unexpectedly.
4. **API Throttling Mitigation**: 
   - Polling loops use throttled intervals with responsive non-blocking key listeners.
   - Tenant-wide calendar discovery includes explicit volume warnings.
   - Interactive user lookups cap result sets to 50 items.
5. **Localization Resiliency**: Resolves localized Exchange folder naming schemes dynamically to prevent command failures on non-English mailboxes.

---

## Troubleshooting & FAQ

#### Q: "No active Exchange Online session detected"
- **Solution**: Run `Run.bat` or launch PowerShell with Internet connectivity. Check if your account requires interactive MFA. If switching tenants, select Option `1` in the switch menu to re-authenticate.

#### Q: "Failed to query Unified Audit Log"
- **Solution**: Ensure your account has the **View-Only Audit Logs** or **Audit Logs** role assigned in the Microsoft Purview Compliance Portal or Microsoft 365 Defender. Note that audit records in Exchange Online can take up to 15-30 minutes to appear after an event occurs.

#### Q: Auto-Expanding Archive option says it cannot be disabled
- **Explanation**: This is by Microsoft design. Microsoft Exchange Online does not support disabling auto-expanding archive storage once it has been provisioned on a mailbox.

#### Q: How do I export data to Excel?
- **Solution**: Use the `[E]` option available in both Bulk Operations and the Unified Audit Log viewer, or Option `4` in Folder Statistics. All reports output RFC-compliant UTF-8 CSV files with automatic timestamping.
