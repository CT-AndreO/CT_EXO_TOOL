# EXO Tool 

A lightweight powershell based tool to simplify management of auto archival, auto expansion, calendar delegation, and bulk management for mailboxes/calendars.

It handles the Exchange Online module loading for you and shows your current tenant right in the menu, making it easy to switch tenants.

---
### Running the programme

Just double click Run.bat to launch.
(Using the batch file automatically bypasses PowerShell execution policies, there is no need to mess with local security settings).

---
```
EXO_Tool/
│
├── Main.ps1                
├── Run.bat                  
│
└── Functions/
    ├── Startup/
    │   ├── DependencyCheck.ps1
    │   ├── Search.ps1
    │   ├── SignIn.ps1
    │   └── Switch.ps1
    │
    ├── Mailbox/
    │   ├── 0_UserHub.ps1
    │   ├── 1_ManageArchive.ps1
    │   ├── 2_ManageExpansion.ps1
    │   ├── 3_StorageMonitor.ps1
    │   ├── 4_CalendarSharing.ps1
    │   └── Utils/
    │       └── Helpers.ps1
    │
    └── Bulk/
        ├── BulkOperations.ps1
        └── ExportReport.ps1
```
### Program Menu & Option Breakdown

#### Main Menu

- **1. Single User Management**: Access individual mailbox controls via user search (Name, UPN, or Email).
- **2. Bulk Operations & Reporting**: Manage or audit multiple mailboxes and directories at scale.
- **3. Switch Tenant / Sign Out**: Change your active organizational context or sign out.
- **0. Exit**: Close the application.
#### Single User Hub (`Option 1`)

Once a target user is selected, you are brought to their specific management suite:

- **1. Manage Archival Rules**: Check archive status, view MRM policy tag mappings (e.g., 1-year, 5-year, never move rules), view/change system policies, or force-run the Managed Folder Assistant.
- **2. Manage Auto Expansion**: View and control the status of auto-expanding archive storage limits.
- **3. Monitor Mailbox Storage (Live Analytics)**: Real-time tracking dashboard showing storage quotas, live usage metrics, applied retention rules, and active session duration with hotkeys for immediate refresh (`R`) or exit (`B`).
- **4. Manage Calendar Sharing**: Access calendar delegation tools to view inbound/outbound permissions, grant external calendar access, or revoke shared access.
- **0. Back to User Search**: Return to the user lookup prompt.
#### Bulk Operations & Reporting (`Option 2` from Main Menu)

An interactive workspace matrix displaying loaded directory objects, state toggles, and processing pipelines:

- **Selection Commands (`[#]`, `[A]`, `[D]`)**: Toggle specific items by index, select all, or clear choices.
- **Filter & Settings (`[T]`, `[L]`, `[V]`)**: Change threshold values for primary/archive limits, toggle license guardrails, or run automated selection evaluation passes.
- **Layout & Data (`[VIEW1]`, `[VIEW2]`, `[E]`, `[R]`)**: Switch views between storage layouts and delegation rules matrix, export directory data to an Excel-friendly CSV, or force-flush/rescan live cache metrics.
- **Cloud Pipelines (`[STOR0]` - `[STOR3]`)**: Configure target switch action modes and bulk process online archiving infrastructure or auto-expanding storage parameters.
- **0. Return to Main Script Menu**: Go back up to the primary application root.
