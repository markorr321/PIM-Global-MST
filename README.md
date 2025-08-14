# 🔐 PIM-Global-MST

Latest Release

> **Now available as a standalone `.exe`** in v3.0.0 – no PowerShell required, with Microsoft Teams integration.

PIM-Global-MST is a lightweight, secure desktop utility designed to streamline Entra ID Privileged Identity Management (PIM) role activation with Microsoft Teams notifications and approval workflows.

---

> 🚀 **Enhanced Version Released!**  
> `PIM-Global-Teams-v2.ps1` now supports **Microsoft Teams integration**, **Power Automate workflows**, **phishing-resistant passwordless MFA**, **multi-role operations**, and **active role detection**.  
> View the [configuration guide](CONFIGURATION.md) →

## 🚀 Key Features

### **Advanced Authentication**
* 🔐 **Phishing-resistant passwordless MFA** with platform and portable passkeys
* 🔄 **Authentication Context handling** - seamless conditional access management
* 🌍 **Multi-tenant support** across global deployments
* 🛡️ **MSAL & Microsoft.Graph-based** secure authentication

### **Enhanced PIM Management**
* ✅ **Portable executable** — no script editing or PowerShell knowledge required
* 📋 **Dual-mode operation** — role activation and deactivation in one unified tool
* 🔍 **Active role detection** — automatically identifies currently active roles
* ⚡ **Multi-role operations** — activate or deactivate multiple roles simultaneously
* 🔄 **Interactive session mode** — multiple operations without re-authentication
* 🎨 **Color-coded output** — enhanced visual feedback and error handling
* 🛑 **Smart deactivation workflow** — safely deactivate roles with justification tracking

### **Microsoft Teams Integration**
* 📱 **Rich adaptive cards** for role activation notifications
* 🔔 **Approval workflow cards** for roles requiring approval
* ⏰ **Timezone-aware timestamps** with proper abbreviations
* 🎯 **Separate channels** for notifications vs approvals
* 🔄 **Power Automate integration** for automated approval workflows

---

## 🔐 Permissions

When you run the tool for the first time, Microsoft will prompt you to sign in and approve access to Microsoft Graph permissions:

| Permission | Why It's Needed |
|------------|----------------|
| User.Read | To identify you and sign in securely |
| GroupMember.Read.All | To read group-based PIM role eligibilities |
| RoleManagement.Read.Directory | To view which PIM roles you're eligible for |
| RoleManagement.ReadWrite.Directory | To activate/deactivate eligible roles on your behalf |
| Directory.Read.All | To read directory information for role operations |

📌 These permissions are **delegated** meaning they only apply while you're signed in interactively using MFA.

👉 If you're the first person in your tenant to use the tool, Microsoft Entra may ask your admin to approve the requested permissions. This is a one-time step built into the Microsoft sign-in experience – no separate setup or consent URL is needed.

---

## ✅ Requirements

### **Mandatory**
* Windows 10/11 (x64)
* PowerShell 7+ (automatically detected)
* Entra ID Premium P2 license (for PIM functionality)
* Eligible PIM roles in your tenant

### **Optional (for Teams integration)**
* Microsoft Teams access
* Teams channel management permissions
* Power Automate Premium license (for approval workflows)

### **Auto-installed Dependencies**
The tool automatically installs required PowerShell modules:
* `Microsoft.Graph` - Graph API PowerShell SDK
* `MSAL.PS` - Microsoft Authentication Library

---

## 🧑‍💻 Usage

### **Option A** — Download Portable Executable (Recommended)

1. **Download** `PIM-Global-MST.exe` from [releases](https://github.com/markorr321/PIM-Global-MST/releases)
2. **Run** the executable - no installation required
3. **Follow** the authentication prompts
4. **Configure** Teams integration (optional) - see [configuration guide](CONFIGURATION.md)

### **Option B** — Run PowerShell Script Directly

**Clone and run locally (Recommended):**
```bash
git clone https://github.com/markorr321/PIM-Global-MST.git
cd PIM-Global-MST
.\PIM-Global-Teams-v2.ps1
```

**Quick Start Script:**
```powershell
# One-line installer and runner
irm https://github.com/markorr321/PIM-Global-MST/raw/main/install.ps1 | iex
```

---

## 🧠 Example Workflow

### 🟢 Launch the Tool

---

### 👤 Account Selection
![Account Selection](images/PIM-MST-Images/Step%201%20-%20Accout%20Selection.png)

---

### 🔑 Passkey Authentication
![Passkey Authentication](images/PIM-MST-Images/Step%202%20-%20Passkey%20Selection.png)

---

### 📷 QR Code Verification
![QR Code Verification](images/PIM-MST-Images/Step%203%20-%20QR%20Code%20Capture.png)

---

### ✅ MFA Confirmation
![MFA Confirmation](images/PIM-MST-Images/Step%204%20-%20Device%20Connection%20Notification.png)

---

### 🎭 Role Selection
![Role Selection](images/PIM-MST-Images/Step%205%20-%20Role%20Selection.png)

---

### 🧾 Role Configuration
![Role Configuration](images/PIM-MST-Images/Step%206%20-%20Enter%20the%20Selected%20Roles.png)

---

### ⏳ Duration Selection
![Duration Selection](images/PIM-MST-Images/Step%207%20-%20Enter%20Duration.png)

---

### 📝 Justification
![Justification](images/PIM-MST-Images/Step%208%20-%20Justification.png)

---

### 🖥️ Role Activation Request Submitted!
![Role Activation Request Submitted](images/PIM-MST-Images/Step%209%20-%20Request%20Submitted.png)

---

## ➕ Additional Activations
![Additional Activations](images/PIM-MST-Images/Step%2010%20-%20Additonal%20Activation.png)

---

## 🚪 Exit the Application
![Exit the Application](images/PIM-MST-Images/Step%2011%20-%20Exit%20Terminal.png)


---

## 📩 Microsoft Teams Approval Workflow

In addition to the in-terminal role activation process, requests can also be handled through Microsoft Teams for a more collaborative and transparent approval process.  
This workflow leverages **Teams channels**, **Adaptive Cards**, and built-in approval notifications to streamline role activation, making it easy for managers and requestors to track the status without leaving Teams.

---

### 🗂️ Navigate to the Channel
![Navigate to the Channel](images/PIM-MST-Images/Approval%20Step%201.png)

---

### 📝 Adaptive Card Example
![Adaptive Card Example](images/PIM-MST-Images/Approval%20Step%202.png)

---

### ✍️ Enter the Approval Notification
![Enter the Approval Notification](images/PIM-MST-Images/Approval%20Step%203.png)

---

### 📌 Posted for Approval (Cannot Be Modified)
![Posted for Approval](images/PIM-MST-Images/Approval%20Step%204.png)

---

### 🔔 Notification for the Requestor
![Notification for the Requestor](images/PIM-MST-Images/Approval%20Step%205.png)


## 🛑 Deactivation Workflow

### 🛡️ Why Prompt Deactivation Matters
As administrators, our privileged accounts grant elevated access to critical systems, sensitive data, and high-impact configurations.  
Leaving these roles active after completing a task — or while not actively engaged — increases the **attack surface** for malicious actors.  

By **promptly deactivating** elevated roles:  
- **🔒 Reduce Risk Exposure** – Limit the time window in which credentials could be exploited if compromised.  
- **📉 Minimize Insider Threat Potential** – Prevent accidental or unauthorized changes during idle periods.  
- **📊 Strengthen Audit Readiness** – Demonstrate adherence to least privilege and just-in-time access principles.  
- **⚡ Improve Operational Discipline** – Encourage a culture where elevated access is temporary, purposeful, and monitored.  

This proactive approach directly improves your organization’s **security posture** while ensuring compliance with modern **identity governance best practices**.

---

### **Intelligent Role Deactivation**
PIM-Global-MST automatically detects active roles and provides a streamlined deactivation process.

---

### **Key Features**
- **🔍 Active Role Detection** - Automatically scans and identifies currently active PIM roles.
- **📋 Bulk Deactivation** - Deactivate multiple active roles simultaneously.  
- **📝 Justification Tracking** - Required justification for all deactivation actions.
- **📱 Teams Notifications** - Sends deactivation notifications to configured Teams channels.
- **🔄 Session Continuity** - Deactivate roles without re-authentication in the same session.
- **⚡ Smart Filtering** - Only shows roles that can be deactivated (excludes permanent assignments).

---

### **Deactivation Process**

#### 1️⃣ Account Selection
![Account Selection](images/PIM-MST-Images/Deactivation%20Workflow/Dactivation%20Step%201%20-%20Account%20Selection.png)

#### 2️⃣ Passkey Sign-In
![Passkey Sign-In](images/PIM-MST-Images/Deactivation%20Workflow/Deactivation%20Step%202%20-%20Passkey%20Sigin.png)

#### 3️⃣ QR Code Verification
![QR Code Verification](images/PIM-MST-Images/Deactivation%20Workflow/Deactivation%20Step%203%20-%20QR%20Code%20Selection.png)

#### 4️⃣ Device Connection
![Device Connection](images/PIM-MST-Images/Deactivation%20Workflow/Deactivation%20Step%204%20-%20Device%20Connection.png)

#### 5️⃣ Active Role Retrieval
![Active Role Retrieval](images/PIM-MST-Images/Deactivation%20Workflow/Deactivation%20Step%205%20-%20Active%20Role%20Retrieval.png)

#### 6️⃣ Confirm Deactivation Prompt
![Confirm Deactivation Prompt](images/PIM-MST-Images/Deactivation%20Workflow/Deactivation%20Step%206%20-%20Enter%20Yes.png)

#### 7️⃣ Role Selection
![Role Selection](images/PIM-MST-Images/Deactivation%20Workflow/Deactivation%20Step%207%20-%20Role%20Selection.png)

#### 8️⃣ Enter Justification
![Enter Justification](images/PIM-MST-Images/Deactivation%20Workflow/Deactivation%20Step%208%20-%20Enter%20Justification.png)

#### 9️⃣ Deactivate Roles
![Deactivate Roles](images/PIM-MST-Images/Deactivation%20Workflow/Deactivation%20Step%209%20-%20Deactivate%20the%20Roles.png)

#### 🔟 Role Management
![Role Management](images/PIM-MST-Images/Deactivation%20Workflow/Deactivation%20Step%2010%20-%20Role%20Management.png)

#### 1️⃣1️⃣ Close the Application
![Close the Application](images/PIM-MST-Images/Deactivation%20Workflow/Deactivation%20Step%2011%20-%20Close%20the%20Application.png)

---

### **Deactivation Workflow Benefits**
- **🛡️ Security Compliance** - Ensures roles are deactivated when no longer needed.
- **📊 Audit Trail** - Complete justification and timestamp logging.
- **⏱️ Time Savings** - Bulk operations reduce administrative overhead.  
- **🔔 Transparency** - Teams notifications keep stakeholders informed.
- **🎯 Precision** - Only shows roles that can actually be deactivated.

---

### **Example Deactivation Scenario**


## 🔧 Configuration

### **Basic Setup (No Teams)**
The tool works out-of-the-box for PIM functionality. To disable Teams notifications:

1. Set `$enableTeamsNotifications = $false` in the script
2. Or ignore the friendly "workflow not configured" messages

### **Teams Integration Setup**
For full Teams integration with notifications and approval workflows:

📖 **[Complete Configuration Guide](CONFIGURATION.md)**

Key setup steps:
1. **Create Teams webhooks** in your notification channels
2. **Configure webhook URLs** in the script
3. **Set up Power Automate flows** for approval automation (optional)
4. **Test the integration** with a role activation

---

## 🔐 Security Features

This tool implements enterprise-grade security:

* **MSAL interactive login** with ACRS enforcement (`acrs=c1`)
* **Phishing-resistant MFA** support (passkeys, Windows Hello, FIDO2)
* **No passwords or secrets stored** - uses secure token-based authentication
* **Conditional Access compliance** - handles authentication contexts seamlessly
* **Temporary file cleanup** - no permanent files left on system
* **Delegated permissions only** - works within user's existing permissions

---

## 🛠️ Advanced Features

### **Multi-Role Operations**
- Activate or deactivate multiple roles in a single session
- Batch processing for efficient role management
- Smart role conflict detection

### **Interactive Session Mode**
- Perform multiple PIM operations without re-authentication
- Session state management across operations
- Automatic token refresh handling

### **Teams Workflow Integration**
- Rich adaptive cards with role details and timestamps
- Separate notification channels for different role types
- Power Automate approval automation
- Timezone-aware notifications

### **Error Handling & User Experience**
- Color-coded console output for better readability
- Comprehensive error messages with suggested solutions
- Graceful fallback when Teams integration isn't configured
- Real-time API synchronization with Entra ID PIM

---

## 📋 Troubleshooting

### Common Issues

**"Teams workflow not configured" messages**
- These are friendly warnings - PIM functionality still works
- Configure Teams integration or set `$enableTeamsNotifications = $false`

**PowerShell 7+ not found**
- Download from [PowerShell releases](https://github.com/PowerShell/PowerShell/releases)
- The tool checks common installation paths automatically

**No eligible roles found**
- Verify you have PIM role assignments in Entra ID → PIM → My Roles
- Check that roles aren't already active

📖 **[Full Troubleshooting Guide](CONFIGURATION.md#troubleshooting)**

---

## 📜 License

MIT License

---

## 🤝 Support & Contributing

### **Get Help**
* 🐛 **Bug Reports**: [GitHub Issues](https://github.com/markorr321/PIM-Global-MST/issues)
* 💬 **Questions**: [GitHub Discussions](https://github.com/markorr321/PIM-Global-MST/discussions)
* 📧 **Development Opportunities**: morr@orr365.tech
* 🐦 **Twitter**: [@MarkHunterOrr](https://twitter.com/MarkHunterOrr)

### **Sponsor Development**
* 💖 **GitHub Sponsors**: [Support this project](https://github.com/sponsors/markorr321)
* ⭐ **Star this repo** to show your support

---

## 🔗 Related Projects

* **[PIM-Global](https://github.com/markorr321/PIM-Global)** - Original PowerShell-only version
* **[PIM-Global-MST](https://github.com/markorr321/PIM-Global-MST)** - This project (executable + Teams integration)

---

*Made with ☕ 3 cups of coffee and 🥤 6 diet cokes by [Mark Orr](https://github.com/markorr321)*  
*Dedicated to Courtney and Aubrey* 💜
