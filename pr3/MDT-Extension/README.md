# MDT Extension for Domain Join and Automated Software Installer

## Overview

This project is an extension for Microsoft Deployment Toolkit (MDT) to automate and enhance operating system deployments. It streamlines device provisioning by automating domain joining, dynamic software installation, and report generation. The extension aims to reduce manual effort, ensure consistency across deployments, and increase overall deployment efficiency.

## Key Features

- **Domain Join Functionality:** Automatically join deployed devices to a specified Active Directory (AD) domain, supporting OU assignment and error logging.
- **Dynamic Software Installation:** Allows selection of software packages during task sequence execution and fetches the latest versions from a central repository.
- **Software Repository Management:**  *(Planned)* A centralized repository for managing software packages and versions. Currently, software download URLs are configured directly in `config.xml`.
- **HTML Report Generation:** Generates detailed HTML reports summarizing deployment, domain join, and software installation status.
- **Customization and Scalability:** Offers customization via configuration files and scalability to support various environments.
- **Windows Activation:** Automates Windows activation using a product key from `config.xml` or KMS/MAK.

## Directory Structure

```
MDT-Extension/
├── Configuration/     # Configuration files (e.g., config.xml)
├── Documentation/     # Project documentation
├── DomainJoin/        # Domain join scripts (e.g., DomainJoin.ps1)
├── ReportGenerator/   # Report generation scripts (e.g., ReportGenerator.ps1)
├── RepositoryManager/ # Scripts for managing the software repository
├── SoftwareInstaller/ # Software installation scripts (e.g., SoftwareInstaller.ps1)
├── Tests/             # Test scripts and related files
└── README.md          # Project overview and instructions (this file)
```

## Configuration

The `config.xml` file in the `Configuration` directory is used to configure the extension. Edit this file to set up domain join credentials, software repository paths, and other settings.

Specifically, you can configure:

- Device naming prefix
- Domain join settings (domain name, OU path, credentials)
- Windows product key
- Software packages for installation (name, display name, download URL, silent install arguments)

## PowerShell Scripts

- **DomainJoin.ps1:**  Located in `DomainJoin/`, this script handles the domain join process.
- **SoftwareInstaller.ps1:** Located in `SoftwareInstaller/`, this script manages software installation.
- **ReportGenerator.ps1:** Located in `ReportGenerator/`, this script generates deployment reports.

## Getting Started

1.  **Configuration:** Modify `MDT-Extension/Configuration/config.xml` with your specific settings.
2.  **Scripts:**  Edit the PowerShell scripts in `DomainJoin/`, `SoftwareInstaller/`, and `ReportGenerator/` to implement the desired logic for each feature.
3.  **Integration with MDT:**  Integrate these scripts into your MDT task sequence to automate domain join and software installation during deployment.
4.  **Testing:**  Use the `Tests/` directory to create and run test scripts to validate the extension.
5.  **Documentation:** Refer to the `Documentation/` directory for detailed documentation (to be added).

## Next Steps

- **Complete Software Repository Management:** Implement scripts for managing a centralized software repository with version control.
- **Enhance Reporting:** Add more detailed logging and error reporting to the HTML reports.
- **完善文档 (Complete Documentation):**  Create comprehensive documentation in the `Documentation/` directory, including setup instructions, configuration details, and troubleshooting guides.
- **Implement Testing:** Write and implement test scripts in the `Tests/` directory to ensure the extension functions correctly and reliably.