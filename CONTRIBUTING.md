# Contributing Guidelines
Thank you for your interest in contributing to the DeFiHackLabs project! We appreciate your efforts to help us maintain a comprehensive collection of DeFi hack incidents and their respective proof-of-concept (POC) exploits. This guide will walk you through the process of adding a new incident entry to the project.

## Table of Contents
* [Prerequisites](#prerequisites)
* [Adding a New Incident Entry](#adding-a-new-incident-entry)
* [Important Notes](#important-notes)

## Prerequisites
Before getting started, ensure you have the following:
* Python 3.x installed on your system
* Basic knowledge of using the command line
* Required Python packages installed (run `pip install -r requirements.txt` to install them)

## Adding a New Incident Entry
To add a new incident entry to the project, follow these steps:

### Step 1: Fork and Clone the Repository
1. Fork the [DeFiHackLabs repository](https://github.com/SunWeb3Sec/DeFiHackLabs) on GitHub.
2. Clone your forked repository to your local machine:
```bash
git clone https://github.com/your-username-here/DeFiHackLabs.git
```
3. Navigate to the project directory:
```bash
cd DeFiHackLabs
 ```
4. Run the `add_new_entry.py` script:
```bash
python add_new_entry.py
```

5. The script will prompt you with the following workflow:

   ### Initial Setup
   - **Network Selection**: Choose from available networks or add a new one:
      ```bash
      $ python3 add_new_entry.py
      Available networks:
      1. mainnet
      2. blast
      3. optimism
      4. fantom
      5. arbitrum
      6. bsc
      7. moonriver
      8. gnosis
      9. Avalanche
      10. polygon
      11. celo
      12. Base
      13. sei
      14. Add a new network
      15. Exit
      Enter the number corresponding to the network you want to use:
      ```

   ### Adding New Entry vs Processing Existing Files
   The script will ask two main questions:
   1. **"Do you want to add a new incident entry manually? (yes/no)"**
   2. **"Do you want to check for .sol files in 'src/test' missing README.md entries? (yes/no)"**

   ### For New Manual Entry (if you answer "yes" to question 1):

   #### Basic Information
   - **File Name**: Enter the name of the POC file (e.g., `Example_exp.sol`)
   - **Transaction Hash for Timestamp** (optional): If you have an attack transaction hash, the script can automatically extract the timestamp
   - **Timestamp String**: If not using transaction hash, enter manually in format `Mar-21-2024 02:51:33 PM`
   - **Lost Amount**: Enter the amount lost (e.g., `100M USD`, `50 ETH`)
   - **Additional Details**: Provide relevant details (e.g., `Reentrancy`)
   - **Link Reference**: Enter reference links

   #### POC File Creation (optional)
   - **Create Solidity File**: The script asks if you want to create a new Solidity POC file
   - If yes, it will gather additional information:

   #### Auto-Population from Transaction Hash (if available)
   - The script can auto-populate addresses using `cast` commands if you provide a transaction hash
   - **Attacker Address**: Auto-suggested or manually entered
   - **Attack Contract Address**: Auto-suggested or manually entered
   - **Vulnerable Contract Address**: Auto-suggested or manually entered
   - **Attack Transaction Hash**: Used for auto-population
   - **Post-mortem URL**: Manual entry (must start with http:// or https://)
   - **Twitter Analysis URL**: Manual entry (must start with http:// or https://)
   - **Security Research URL**: Manual entry (must start with http:// or https://)

   ### For Processing Existing Files (if you answer "yes" to question 2):
   The script will:
   - Scan for uncommitted `.sol` files in `src/test/` directory
   - Scan for recently committed `.sol` files (from last commit)
   - Check if README entries exist for these files
   - Prompt you to add missing README entries for files without them

### Step 2: Automatic Updates
The script automatically handles:
1. **README.md Updates**: Adds new incident entry to the "List of DeFi Hacks & POCs" section
2. **Table of Contents**: Updates the incident count and adds TOC entry
3. **POC File Generation**: Creates Solidity file from template with auto-populated information
4. **foundry.toml Updates**: Adds new network RPC endpoints if needed
5. **Explorer URL Integration**: Automatically generates blockchain explorer links based on selected network

### Step 3: Implement the Exploit Code
1. If you chose to create a Solidity POC file, it will be generated in `src/test/YYYY-MM/` directory with the template
2. The generated file will have placeholder code in the `testExploit()` function
3. Implement your exploit logic by replacing the placeholder code
4. The file includes auto-generated links to:
   - Attacker addresses on blockchain explorer
   - Attack contract addresses on blockchain explorer
   - Vulnerable contract addresses on blockchain explorer
   - Attack transaction hash on blockchain explorer

### Step 4: Test and Commit Your Changes
1. Test the exploit by running the forge test command (the script will show you the exact command):
 ```bash
   forge test --contracts ./src/test/YYYY-MM/IncidentName_exp.sol -vvv
```
   Note: For certain chains (Base, Optimism, BSC), the script automatically adds `--evm-version shanghai` flag

2. Commit your changes and push them to your forked repository:
```bash
    git add .
    git commit -m "feat: Add POC for IncidentName"
    git push origin main
```

3. Open a pull request from your forked repository to the main DeFiHackLabs repository. Provide a clear description of the incident you added.

4. Our maintainers will review your pull request. They may provide feedback or request further changes. Once your pull request is approved, it will be merged into the main repository.

## Important Notes
 - **The script automatically generates blockchain explorer URLs** - do not paste explorer URLs manually
 - **Transaction hash auto-population**: If you have an attack transaction hash, the script can automatically extract timestamp and suggest attacker/contract addresses using Foundry's `cast` command
 - **Directory structure**: POC files are automatically organized into `src/test/YYYY-MM/` directories based on incident date
 - **Network support**: The script includes support for multiple networks including Sei (newly added)
 - **Template auto-replacement**: POC files are generated from a template with automatic placeholder replacement
 - **Git integration**: The script can process existing uncommitted or recently committed `.sol` files to add missing README entries
 - **URL validation**: The script validates that all URLs start with http:// or https://
 - **Make sure to follow the formatting guidelines and provide accurate information when adding a new incident entry.**
 - **Do not include the UTC offset when copying the timestamp from the transaction details page on the blockchain explorer.**
 - **If you encounter any issues or have questions, please open an issue on the https://github.com/SunWeb3Sec/DeFiHackLabs/issues or reach out to our maintainers.**

We appreciate your contribution to the DeFiHackLabs project. Your efforts help us maintain a valuable resource for the DeFi community to learn from past incidents and improve the security of DeFi protocols. Thank you for your support! 

---