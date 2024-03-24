# Contributing Guidelines

Thank you for your interest in contributing to the DeFiHackLabs project! We appreciate your efforts to help us maintain a comprehensive collection of DeFi hack incidents and their respective proof-of-concept (POC) exploits. This guide will walk you through the process of adding a new incident entry to the project.

## Prerequisites

Before getting started, ensure you have the following:

- Python 3.x installed on your system
- Basic knowledge of using the command line
- `toml` package installed (run `pip install toml` to install it)

## Adding a New Incident Entry

To add a new incident entry to the project, follow these steps:

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

5. The script will prompt you to enter the following information:
   ## Note: do not paste in explorer urls,the script automatically generates them based on the network selected
   - **Network**: Enter the index of the network the exploit was on: here is an example screen you will see when running the script
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
      13. Add a new network
      Enter the number corresponding to the network you want to use:
      ```
   - **File Name**: Enter the name of the POC file in the format `IncidentName_exp.sol`.
   - **Timestamp String**: Enter the timestamp of the incident in the format `Mar-21-2024 02:51:33 PM`. Make sure to copy the timestamp from the incident's transaction details page on the relevant blockchain explorer, without including the UTC offset. (ie the +UTC part of the time)
   - **Lost Amount**: Enter the amount lost in the incident.
   - **Additional Details**: Provide any additional relevant details about the incident.
   - **Link Reference**: Enter the link to the reference material or source of information.
   - **Attacker's Address**: Enter the attacker's address.
   - **Attack Contract Address**: Enter the address of the contract used in the attack.
   - **Vulnerable Contract Address**: Enter the address of the vulnerable contract.
   - **Attack Transaction Hash**: Enter the transaction hash of the attack.
   - **Post-mortem URL**: Enter the URL to the post-mortem analysis of the incident.
   - **Twitter Guy URL**: Enter the URL to a Twitter thread or user providing insights about the incident.
   - **Hacking God URL**: Enter the URL to a write-up or analysis by a respected security researcher or hacker.

6. The script will ask if you want to create a new Solidity file for the POC. If you choose "yes", it will generate a new file in the `src/test/` directory with the provided information and a template for the exploit code.

7. The script will update the `README.md` file with the new incident entry and add it to the table of contents.

8. Implement the exploit code in the generated Solidity file (e.g., `IncidentName_exp.sol`) by replacing the placeholder code in testExploit with your exploit POC logic.

9. Test the exploit by running the following command:
   ```bash
   forge test --contracts ./src/test/IncidentName_exp.sol -vvv
   ```

10. Commit your changes and push them to your forked repository:
    ```bash
    git add .
    git commit -m "feat: Add POC for IncidentName"
    git push origin main
    ```

11. Open a pull request from your forked repository to the main DeFiHackLabs repository. Provide a clear description of the incident you added.

12. Our maintainers will review your pull request. They may provide feedback or request further changes. Once your pull request is approved, it will be merged into the main repository.

## Important Notes

- Make sure to follow the formatting guidelines and provide accurate information when adding a new incident entry.
- Do not include the UTC offset when copying the timestamp from the transaction details page on the blockchain explorer.
- If you encounter any issues or have questions, please open an issue on the [DeFiHackLabs repository](https://github.com/SunWeb3Sec/DeFiHackLabs/issues) or reach out to our maintainers.

We appreciate your contribution to the DeFiHackLabs project. Your efforts help us maintain a valuable resource for the DeFi community to learn from past incidents and improve the security of DeFi protocols. Thank you for your support!