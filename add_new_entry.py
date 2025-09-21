#!/usr/bin/env python3
"""
DeFi Hack Manager - A tool for documenting and managing DeFi hack POCs
"""

from datetime import datetime
import re
import os
import toml
import subprocess
import json
from typing import Optional, Dict, List, Any, Tuple
import sys
import unittest
from unittest import mock

######################
# CONSTANTS
######################

class Constants:
    # File paths
    FOUNDRY_TOML_PATH = "foundry.toml"
    README_PATH = "README.md"
    POC_TEMPLATE_PATH = "script/Exploit-template_new.sol"
    SRC_TEST_DIR = os.path.join("src", "test")
    
    # Regex patterns
    LIST_OF_HACKS_HEADER_REGEX = r"### List of DeFi Hacks & POCs(.*?)(?=###|\Z)"
    TOC_HEADER_REGEX = r"## List of Past DeFi Incidents"
    INCIDENTS_COUNT_REGEX = r"(\d+)\s+incidents included\."
    
    # Chains requiring shanghai EVM version
    SHANGHAI_EVM_CHAINS = ["Base", "optimism", "bsc"]
    
    # Explorer URLs
    EXPLORER_URLS = {
        "mainnet": "https://etherscan.io",
        "blast": "https://blastscan.io",
        "optimism": "https://optimistic.etherscan.io",
        "fantom": "https://ftmscan.com",
        "arbitrum": "https://arbiscan.io",
        "bsc": "https://bscscan.com",
        "moonriver": "https://moonriver.moonscan.io",
        "gnosis": "https://gnosisscan.io",
        "Avalanche": "https://snowtrace.io",
        "polygon": "https://polygonscan.com",
        "celo": "https://celoscan.io",
        "Base": "https://basescan.org",
        "sei": "https://seiscan.io/"
    }
    
    # POC Template Placeholders
    POC_TEMPLATE_REPLACEMENTS = {
        "lost_amount": "~999M US$",
        "attacker_address": "0xcafebabe",
        "attack_contract_address": "attackcontractaddrhere",
        "vulnerable_contract_address": "vulcontractaddrhere",
        "attack_tx_hash": "0x123456789",
        "vulnerable_contract_code_url": "https://etherscan.io/address/0xdeadbeef#code",
        "post_mortem_url": "postmortemurlhere",
        "twitter_guy_url": "twitterguyhere",
        "hacking_god_url": "hackinggodhere",
        "exploit_script_name": "ExploitScript",
        "network_name": "mainnet",
        "base_test_path": "../src/test/basetest.sol"
    }


######################
# LIBRARY
######################

class DefiHackLibrary:
    """Central library class for managing DeFi hack documentation"""
    
    def __init__(self, config_path=None, readme_path=None, template_path=None, src_test_dir=None):
        """Initialize with optional custom paths"""
        self.constants = Constants()
        
        # Override defaults with custom paths if provided
        if config_path:
            self.constants.FOUNDRY_TOML_PATH = config_path
        if readme_path:
            self.constants.README_PATH = readme_path
        if template_path:
            self.constants.POC_TEMPLATE_PATH = template_path
        if src_test_dir:
            self.constants.SRC_TEST_DIR = src_test_dir
            
        # Initialize sub-components
        self.config_manager = ConfigManager(self.constants)
        self.transaction_manager = TransactionManager(self.constants)
        self.readme_manager = ReadmeManager(self.constants)
        self.poc_manager = PocManager(self.constants, self.config_manager)
        self.git_manager = GitManager(self.constants)

    def select_network(self) -> Tuple[Optional[str], Dict[str, str]]:
        """Select a network from available RPC endpoints or add a new one"""
        return self.config_manager.select_network()
    
    def add_new_entry(self, selected_network: str) -> None:
        """Add a new DeFi hack entry"""
        rpc_endpoints = self.config_manager.parse_foundry_toml()
        
        # Get basic file info
        file_info = self.get_file_info(selected_network, rpc_endpoints)
        file_name, timestamp_str, lost_amount, additional_details, link_reference, attack_tx_hash = file_info
        
        # Optionally create POC file
        if input("Do you want to create a new Solidity file for this POC? (yes/no): ").lower() == "yes":
            # Get extra info for POC file
            extra_info = self.get_file_extra_info(selected_network, rpc_endpoints, attack_tx_hash)
            attacker_address, attack_contract_address, vulnerable_contract_address, attack_tx_hash, post_mortem_url, twitter_guy_url, hacking_god_url = extra_info
            
            # Create POC file
            self.poc_manager.create_poc_solidity_file(file_name, lost_amount, attacker_address, attack_contract_address,
                                                    vulnerable_contract_address, attack_tx_hash,
                                                    post_mortem_url, twitter_guy_url, hacking_god_url, 
                                                    selected_network, timestamp_str)
        
        # Update README
        timestamp = self.transaction_manager.get_timestamp_from_str(timestamp_str)
        formatted_date = timestamp.strftime("%Y%m%d")
        name = file_name.split("_")[0]
        
        self.readme_manager.update_readme(formatted_date, name, additional_details, 
                                        lost_amount, file_name, link_reference, selected_network)
        
        # Update foundry.toml if needed
        if selected_network not in self.config_manager.parse_foundry_toml():
            print(f"Updating {self.constants.FOUNDRY_TOML_PATH} with new network: {selected_network}")
            self.config_manager.update_foundry_toml({**self.config_manager.parse_foundry_toml(), 
                                                  selected_network: rpc_endpoints[selected_network]})
    
    def get_file_info(self, selected_network: str, rpc_endpoints: dict) -> Tuple:
        """Get basic information about the hack file"""
        print("NOTE: The script automatically adds explorer URLs for any address provided.")
        file_name = input("Enter the file name (e.g., Example_exp.sol): ").strip()
        while not file_name:
            print("File name cannot be empty.")
            file_name = input("Enter the file name (e.g., Example_exp.sol): ").strip()
        
        timestamp_str = ""
        attack_tx_hash_for_timestamp = ""
        
        # Try to get timestamp from transaction hash
        if selected_network and selected_network in rpc_endpoints and self.transaction_manager.is_cast_command_available():
            if input("Do you have an attack transaction hash to get the timestamp? (yes/no): ").lower() == 'yes':
                attack_tx_hash_for_timestamp = input("Enter the attack transaction hash for timestamp: ").strip()
                if attack_tx_hash_for_timestamp:
                    timestamp_str = self.transaction_manager.get_timestamp_from_tx_hash(
                        attack_tx_hash_for_timestamp, rpc_endpoints[selected_network])
        
        # If timestamp wasn't obtained from transaction, ask user
        if not timestamp_str:
            timestamp_str = input("Enter the timestamp string (e.g., Mar-21-2024 02:51:33 PM) or leave empty to use current timestamp: ").strip()
        
        # Get other details
        lost_amount_str = input("Enter the lost amount (e.g., 100M USD, 50 ETH): ").strip()
        while not lost_amount_str:
            print("Lost amount cannot be empty.")
            lost_amount_str = input("Enter the lost amount: ").strip()
        
        additional_details = input("Enter additional details (e.g., Reentrancy): ").strip()
        link_reference = input("Enter the link reference: ").strip()
        
        return file_name, timestamp_str, lost_amount_str, additional_details, link_reference, attack_tx_hash_for_timestamp
    
    def get_file_extra_info(self, selected_network: str, rpc_endpoints: dict, initial_tx_hash: str = None) -> Tuple:
        """Get additional information about the hack for POC file creation"""
        attacker_address = ""
        attack_contract_address = ""
        vulnerable_contract_address = ""
        attack_tx_hash = ""
        
        # Try to use provided tx hash or ask for one
        current_tx_hash_to_use = initial_tx_hash
        if not current_tx_hash_to_use:
            if input("Do you have an attack transaction hash to try auto-populating addresses? (yes/no): ").lower() == 'yes':
                current_tx_hash_to_use = input("Enter the attack transaction hash: ").strip()
        
        # If we have a tx hash and can use cast, get suggested values
        if selected_network and selected_network in rpc_endpoints and self.transaction_manager.is_cast_command_available() and current_tx_hash_to_use:
            suggested_values = self.transaction_manager.get_addresses_from_tx_hash(
                current_tx_hash_to_use, rpc_endpoints[selected_network])
            
            if suggested_values:
                suggested_attacker, suggested_attack_contract, suggested_vulnerable_contract = suggested_values
                
                print("\n--- Suggested values based on transaction hash ---")
                if suggested_attacker: print(f"Suggested Attacker Address: {suggested_attacker}")
                if suggested_attack_contract: print(f"Suggested Attack Contract Address: {suggested_attack_contract}")
                if suggested_vulnerable_contract: print(f"Suggested Vulnerable Contract Address: {suggested_vulnerable_contract}")
                print("--------------------------------------------------")
                
                if input("Use suggested attacker address? (yes/no, or enter manually): ").lower() == 'yes':
                    attacker_address = suggested_attacker
                if suggested_attack_contract and input("Use suggested attack contract address? (yes/no, or enter manually): ").lower() == 'yes':
                    attack_contract_address = suggested_attack_contract
                if suggested_vulnerable_contract and input("Use suggested vulnerable contract address? (yes/no, or enter manually): ").lower() == 'yes':
                    vulnerable_contract_address = suggested_vulnerable_contract
                attack_tx_hash = current_tx_hash_to_use
            else:
                print("Failed to fetch transaction/receipt details. Please enter manually.")
        
        # Get manual input for values that weren't automatically populated
        if not attacker_address:
            attacker_address = input("Enter the attacker's address: ").strip()
        if not attack_contract_address:
            attack_contract_address = input("Enter the attack contract address (can be same as attacker or a separate contract): ").strip()
        if not vulnerable_contract_address:
            vulnerable_contract_address = input("Enter the vulnerable contract address: ").strip()
        if not attack_tx_hash:
            attack_tx_hash = input("Enter the attack transaction hash: ").strip()
        
        # Get URLs
        post_mortem_url = input("Enter the post-mortem URL (e.g., https://medium.com/...): ").strip()
        while post_mortem_url and not (post_mortem_url.startswith("http://") or post_mortem_url.startswith("https://")):
            print("Invalid URL. It should start with 'http://' or 'https://'. Leave empty if not available.")
            post_mortem_url = input("Enter the post-mortem URL: ").strip()
        
        twitter_guy_url = input("Enter the Twitter guy URL (e.g., https://twitter.com/...): ").strip()
        while twitter_guy_url and not (twitter_guy_url.startswith("http://") or twitter_guy_url.startswith("https://")):
            print("Invalid URL. It should start with 'http://' or 'https://'. Leave empty if not available.")
            twitter_guy_url = input("Enter the Twitter guy URL: ").strip()
        
        hacking_god_url = input("Enter the hacking god URL (e.g., https://someblog.com/...): ").strip()
        while hacking_god_url and not (hacking_god_url.startswith("http://") or hacking_god_url.startswith("https://")):
            print("Invalid URL. It should start with 'http://' or 'https://'. Leave empty if not available.")
            hacking_god_url = input("Enter the hacking god URL: ").strip()
        
        return attacker_address, attack_contract_address, vulnerable_contract_address, attack_tx_hash, post_mortem_url, twitter_guy_url, hacking_god_url
    
    def process_existing_files(self):
        """Process existing .sol files that might be missing README entries"""
        uncommitted_sol_files = self.git_manager.get_uncommitted_sol_files()
        if uncommitted_sol_files and any(f.strip() for f in uncommitted_sol_files):
            print("\nProcessing uncommitted .sol files...")
            self._process_sol_files_batch(uncommitted_sol_files)
        else:
            print(f"No uncommitted .sol files found in {self.constants.SRC_TEST_DIR} that are not in .gitignore.")
        
        recently_committed_sol_files = self.git_manager.get_recently_committed_sol_files()
        if recently_committed_sol_files and any(f.strip() for f in recently_committed_sol_files):
            print("\nProcessing recently committed .sol files (from last commit)...")
            self._process_sol_files_batch(recently_committed_sol_files)
        else:
            print(f"No recently committed .sol files found in {self.constants.SRC_TEST_DIR} in the last commit.")
    
    def _process_sol_files_batch(self, sol_files: list):
        """Process a batch of solidity files"""
        for file_path in sol_files:
            if not self.readme_manager.check_readme_entry(file_path):
                print(f"No README entry found for {file_path}. Adding new entry...")
                self._add_new_entry_from_file(file_path)
            else:
                print(f"README entry already exists for {file_path}. Skipping...")
    
    def _add_new_entry_from_file(self, file_path):
        """Add a new entry from an existing solidity file"""
        file_name = os.path.basename(file_path)
        timestamp_str = input(f"Enter the timestamp string for {file_name} (e.g., Mar-21-2024 02:51:33 PM) or leave empty to use current timestamp: ")
        lost_amount = input(f"Enter the lost amount for {file_name}: ")
        additional_details = input(f"Enter additional details for {file_name}: ")
        link_reference = input(f"Enter the link reference for {file_name}: ")
        
        timestamp = self.transaction_manager.get_timestamp_from_str(timestamp_str)
        formatted_date = timestamp.strftime("%Y%m%d")
        name = file_name.split("_")[0]
        
        self.readme_manager.update_readme(formatted_date, name, additional_details, 
                                        lost_amount, file_name, link_reference, None)


class ConfigManager:
    """Manages configuration operations such as reading/writing foundry.toml"""
    
    def __init__(self, constants):
        self.constants = constants
    
    def parse_foundry_toml(self) -> Dict[str, str]:
        """Parse foundry.toml to get RPC endpoints"""
        try:
            with open(self.constants.FOUNDRY_TOML_PATH, "r") as toml_file:
                config = toml.load(toml_file)
                rpc_endpoints = config.get("rpc_endpoints", {})
            return rpc_endpoints
        except FileNotFoundError:
            print(f"Error: {self.constants.FOUNDRY_TOML_PATH} not found. Please ensure the file exists in the current directory.")
            return {}
        except toml.TomlDecodeError:
            print(f"Error: Could not decode {self.constants.FOUNDRY_TOML_PATH}. Please check its format.")
            return {}
    
    def update_foundry_toml(self, rpc_endpoints: dict):
        """Update foundry.toml with new RPC endpoints"""
        try:
            with open(self.constants.FOUNDRY_TOML_PATH, "r") as toml_file:
                config = toml.load(toml_file)
        except FileNotFoundError:
            print(f"Error: {self.constants.FOUNDRY_TOML_PATH} not found. Cannot update RPC endpoints.")
            return
        except toml.TomlDecodeError:
            print(f"Error: Could not decode {self.constants.FOUNDRY_TOML_PATH}. Cannot update RPC endpoints.")
            return
        
        config["rpc_endpoints"] = rpc_endpoints
        
        try:
            with open(self.constants.FOUNDRY_TOML_PATH, "w") as toml_file:
                toml.dump(config, toml_file)
            print(f"{self.constants.FOUNDRY_TOML_PATH} updated successfully.")
        except IOError:
            print(f"Error: Could not write to {self.constants.FOUNDRY_TOML_PATH}.")
    
    def select_network(self) -> Tuple[Optional[str], Dict[str, str]]:
        """Select a network from available RPC endpoints or add a new one"""
        rpc_endpoints = self.parse_foundry_toml()
        
        while True:
            print("\nAvailable networks:")
            networks = list(rpc_endpoints.keys())
            for i, network_name in enumerate(networks, start=1):
                print(f"{i}. {network_name}")
            print(f"{len(networks) + 1}. Add a new network")
            print(f"{len(networks) + 2}. Exit")
            
            choice = input("Enter the number corresponding to the network you want to use: ")
            
            try:
                choice = int(choice)
                if 1 <= choice <= len(networks):
                    selected_network = networks[choice - 1]
                    break
                elif choice == len(networks) + 1:
                    new_network_name = input("Enter the name of the new network (e.g., arbitrum_sepolia): ").strip()
                    while not new_network_name:
                        print("Network name cannot be empty.")
                        new_network_name = input("Enter the name of the new network: ").strip()
                    
                    new_network_url = input(f"Enter the RPC URL for {new_network_name}: ").strip()
                    while not (new_network_url.startswith("http://") or new_network_url.startswith("https://")):
                        print("Invalid RPC URL. It should start with 'http://' or 'https://'.")
                        new_network_url = input(f"Enter the RPC URL for {new_network_name}: ").strip()
                    
                    rpc_endpoints[new_network_name] = new_network_url
                    selected_network = new_network_name
                    print(f"Network '{selected_network}' added and selected.")
                    break
                elif choice == len(networks) + 2:
                    print("Exiting network selection.")
                    return None, rpc_endpoints
                else:
                    print(f"Invalid choice. Please enter a number between 1 and {len(networks) + 2}.")
            except ValueError:
                print("Invalid input. Please enter a valid number.")
        
        return selected_network, rpc_endpoints


class TransactionManager:
    """Manages transaction-related operations"""
    
    def __init__(self, constants):
        self.constants = constants
    
    def is_cast_command_available(self) -> bool:
        """Check if 'cast' command is available"""
        try:
            subprocess.check_output(["cast", "--version"])
            return True
        except (FileNotFoundError, subprocess.CalledProcessError):
            print("Warning: 'cast' command not found. Cannot auto-populate from transaction hash.")
            return False
    
    def _run_cast_command(self, cast_args: List[str], rpc_url: str, command_description: str) -> Optional[Dict[str, Any]]:
        """Helper function to run a 'cast' command"""
        command = ["cast"] + cast_args + ["--rpc-url", rpc_url]
        try:
            result = subprocess.run(command, capture_output=True, text=True, check=True, timeout=30)
            return json.loads(result.stdout)
        except subprocess.CalledProcessError as e:
            print(f"Error calling 'cast' for {command_description}: {e}")
            stderr_output = e.stderr.strip() if e.stderr else "No stderr output."
            print(f"Command: {' '.join(command)}")
            print(f"Stderr: {stderr_output}")
        except json.JSONDecodeError:
            print(f"Error parsing JSON output from 'cast' for {command_description}.")
            print(f"Command: {' '.join(command)}")
        except subprocess.TimeoutExpired:
            print(f"'cast' command timed out for {command_description}.")
            print(f"Command: {' '.join(command)}")
        except Exception as e:
            print(f"An unexpected error occurred with 'cast' for {command_description}: {e}")
            print(f"Command: {' '.join(command)}")
        return None
    
    def get_timestamp_from_str(self, timestampstr: str) -> datetime:
        """Convert timestamp string to datetime object"""
        if not timestampstr:
            return datetime.now()
        try:
            return datetime.strptime(timestampstr, "%b-%d-%Y %I:%M:%S %p")
        except ValueError:
            print("Invalid timestamp format. Please use 'Mon-DD-YYYY HH:MM:SS AM/PM' (e.g., Mar-21-2024 02:51:33 PM).")
            print("Using current timestamp instead.")
            return datetime.now()
    
    def get_timestamp_from_tx_hash(self, tx_hash: str, rpc_url: str) -> str:
        """Get timestamp from transaction hash"""
        print(f"Fetching block number for tx {tx_hash}...")
        tx_data = self._run_cast_command(
            ["tx", tx_hash, "--json"],
            rpc_url,
            f"fetching tx details for {tx_hash}"
        )
        
        if tx_data:
            block_number_hex = tx_data.get("blockNumber")
            if block_number_hex is not None:
                try:
                    block_number = int(str(block_number_hex), 0)
                    print(f"Fetching timestamp for block {block_number}...")
                    block_data = self._run_cast_command(
                        ["block", str(block_number), "--json"],
                        rpc_url,
                        f"fetching block {block_number} details"
                    )
                    
                    if block_data:
                        unix_timestamp_any = block_data.get("timestamp")
                        if unix_timestamp_any is not None:
                            try:
                                if isinstance(unix_timestamp_any, str) and unix_timestamp_any.startswith("0x"):
                                    unix_timestamp = int(unix_timestamp_any, 16)
                                else:
                                    unix_timestamp = int(unix_timestamp_any)
                                
                                dt_object = datetime.fromtimestamp(unix_timestamp)
                                suggested_timestamp_str = dt_object.strftime("%b-%d-%Y %I:%M:%S %p")
                                print(f"Suggested timestamp: {suggested_timestamp_str}")
                                if input("Use suggested timestamp? (yes/no): ").lower() == 'yes':
                                    return suggested_timestamp_str
                            except ValueError:
                                print(f"Could not parse block timestamp: {unix_timestamp_any}")
                        else:
                            print("Could not retrieve timestamp from block data.")
                except ValueError:
                    print(f"Could not parse block number: {block_number_hex}")
            else:
                print("Could not retrieve block number from transaction.")
        
        return ""
    
    def get_addresses_from_tx_hash(self, tx_hash: str, rpc_url: str) -> Optional[Tuple[str, str, str]]:
        """Get addresses from transaction hash"""
        print(f"Fetching transaction and receipt details for {tx_hash}...")
        tx_data = self._run_cast_command(
            ["tx", tx_hash, "--json"],
            rpc_url,
            f"fetching tx details for {tx_hash}"
        )
        receipt_data = self._run_cast_command(
            ["receipt", tx_hash, "--json"],
            rpc_url,
            f"fetching receipt for {tx_hash}"
        )
        
        if tx_data and receipt_data:
            suggested_attacker = tx_data.get("from")
            suggested_vulnerable_contract = tx_data.get("to")
            suggested_attack_contract = ""
            
            if tx_data.get("to") is None and receipt_data.get("contractAddress"):
                suggested_attack_contract = receipt_data.get("contractAddress")
            elif receipt_data.get("contractAddress"):
                print(f"Transaction interacted with {tx_data.get('to')} and also created/has contract address {receipt_data.get('contractAddress')}.")
                print("This could be the attack contract or a related contract.")
            
            return suggested_attacker, suggested_attack_contract, suggested_vulnerable_contract
        
        return None


class ReadmeManager:
    """Manages README operations"""
    
    def __init__(self, constants):
        self.constants = constants
    
    def update_readme(self, formatted_date: str, name: str, additional_details: str, 
                     lost_amount: str, file_name: str, link_reference: str, selected_network: str):
        """Update README.md with a new entry"""
        try:
            with open(self.constants.README_PATH, "r") as file:
                content = file.read()
        except FileNotFoundError:
            print(f"Error: {self.constants.README_PATH} not found. Please ensure the file exists in the current directory.")
            print("Aborting README.md update.")
            return
        
        updated_content = self._update_readme_contents(content, formatted_date, name, 
                                                    additional_details, lost_amount, 
                                                    file_name, link_reference, selected_network)
        
        with open(self.constants.README_PATH, "w") as file:
            file.write(updated_content)
        
        print(f"Updated {self.constants.README_PATH} with new entry: {formatted_date} {name}")
    
    def _update_readme_contents(self, content: str, formatted_date: str, name: str, 
                              additional_details: str, lost_amount: str, file_name: str, 
                              link_reference: str, selected_network: str) -> str:
        """Helper function to generate new entry and update README content sections"""
        new_entry = self._generate_new_entry(formatted_date, name, additional_details, 
                                          lost_amount, file_name, link_reference, selected_network)
        updated_content = self._insert_new_entry(content, new_entry)
        updated_content = self._update_table_of_contents(updated_content, formatted_date, name, additional_details)
        updated_content = self._update_sum_of_incidents(updated_content)
        return updated_content
    
    def _generate_new_entry(self, formatted_date, name, additional_details, lost_amount, file_name, link_reference, selected_network):
        """Generate a new README entry"""
        run_command = self._get_run_command(formatted_date, file_name, selected_network)
        return f"""
### {formatted_date} {name} - {additional_details}

### Lost: {lost_amount}


```sh
{run_command}
```
#### Contract
[{file_name}]({self.constants.SRC_TEST_DIR}/{formatted_date[:4]}-{formatted_date[4:6]}/{file_name})
### Link reference

{link_reference}

---

"""
    
    def _insert_new_entry(self, content, new_entry):
        """Insert new entry into the README content"""
        match = re.search(self.constants.LIST_OF_HACKS_HEADER_REGEX, content, re.DOTALL)
        if not match:
            print(f"Error: Could not find insertion point in {self.constants.README_PATH} using regex: {self.constants.LIST_OF_HACKS_HEADER_REGEX}")
            print("New entry will be appended at the end of the file instead.")
            return content + "\n\n" + new_entry
        insert_pos = match.end()
        return content[:insert_pos].strip() + "\n\n" + new_entry.strip() + "\n\n" + content[insert_pos:].strip()
    
    def _update_table_of_contents(self, content: str, formatted_date: str, name: str, additional_details: str) -> str:
        """Update the table of contents in README"""
        sanitized_name = re.sub(r'[^a-zA-Z0-9\s-]', '', name.lower())
        sanitized_details = re.sub(r'[^a-zA-Z0-9\s-]', '', additional_details.lower())
        link = f"#{formatted_date}-{sanitized_name}---{sanitized_details.replace(' ', '-')}"
        toc_entry = f"[{formatted_date} {name}]({link})"
        match = re.search(self.constants.TOC_HEADER_REGEX, content)
        if not match:
            print(f"Error: Could not find Table of Contents section in {self.constants.README_PATH} using regex: {self.constants.TOC_HEADER_REGEX}")
            print("Table of Contents entry will not be added.")
            return content
        toc_insert_pos = match.end()
        return content[:toc_insert_pos].strip() + "\n" + toc_entry + "\n" + content[toc_insert_pos:].strip()
    
    def _update_sum_of_incidents(self, content: str) -> str:
        """Update the sum of incidents in README"""
        match = re.search(self.constants.INCIDENTS_COUNT_REGEX, content)
        if match:
            old_number = int(match.group(1))
            new_number = old_number + 1
            return content[:match.start()] + f"{new_number} incidents included." + content[match.end():]
        return content
    
    def _get_run_command(self, formatted_date: str, file_name: str, chain: Optional[str]) -> str:
        """Get the forge test run command"""
        basecommand = f"""forge test --contracts ./{self.constants.SRC_TEST_DIR}/{formatted_date[:4]}-{formatted_date[4:6]}/{file_name} -vvv"""
        if chain is not None and chain in self.constants.SHANGHAI_EVM_CHAINS:
            basecommand = basecommand + " --evm-version shanghai"
        return basecommand
    
    def check_readme_entry(self, file_path: str) -> bool:
        """Check if a README entry exists for a file"""
        try:
            with open(self.constants.README_PATH, "r") as file:
                content = file.read()
            file_name = os.path.basename(file_path)
            return file_name in content
        except FileNotFoundError:
            print(f"Error: {self.constants.README_PATH} not found. Cannot check for existing entries.")
            return False


class PocManager:
    """Manages POC file operations"""
    
    def __init__(self, constants, config_manager):
        self.constants = constants
        self.config_manager = config_manager
    
    def create_poc_solidity_file(self, file_name: str, lost_amount: str, attacker_address: str, 
                                attack_contract_address: str, vulnerable_contract_address: str, 
                                attack_tx_hash: str, post_mortem_url: str, twitter_guy_url: str, 
                                hacking_god_url: str, selected_network: str, timestamp_str: str):
        """Create a new Solidity POC file from template"""
        # Parse timestamp and format date for path
        timestamp = datetime.strptime(timestamp_str, "%b-%d-%Y %I:%M:%S %p") if timestamp_str else datetime.now()
        formatted_date_for_path = timestamp.strftime("%Y-%m")
        
        # Ensure file name has proper extension
        new_file_name = file_name.replace("_exp.sol", "") + "_exp.sol"
        new_file_path = os.path.join(self.constants.SRC_TEST_DIR, formatted_date_for_path, new_file_name)
        
        # Create directory if it doesn't exist
        os.makedirs(os.path.dirname(new_file_path), exist_ok=True)
        
        # Read template
        try:
            with open(self.constants.POC_TEMPLATE_PATH, "r") as template_file:
                template_content = template_file.read()
        except FileNotFoundError:
            print(f"Error: {self.constants.POC_TEMPLATE_PATH} not found. Cannot create POC file.")
            return
        
        # Get explorer URL for selected network
        explorer_url = self.constants.EXPLORER_URLS.get(selected_network, "")
        name_part = file_name.split("_")[0]
        
        # Prepare replacements
        replacements = {
            self.constants.POC_TEMPLATE_REPLACEMENTS["lost_amount"]: lost_amount,
            self.constants.POC_TEMPLATE_REPLACEMENTS["attacker_address"]: f"{explorer_url}/address/{attacker_address}" if attacker_address else "N/A",
            self.constants.POC_TEMPLATE_REPLACEMENTS["attack_contract_address"]: f"{explorer_url}/address/{attack_contract_address}" if attack_contract_address else "N/A",
            self.constants.POC_TEMPLATE_REPLACEMENTS["vulnerable_contract_address"]: f"{explorer_url}/address/{vulnerable_contract_address}" if vulnerable_contract_address else "N/A",
            self.constants.POC_TEMPLATE_REPLACEMENTS["attack_tx_hash"]: f"{explorer_url}/tx/{attack_tx_hash}" if attack_tx_hash else "N/A",
            self.constants.POC_TEMPLATE_REPLACEMENTS["vulnerable_contract_code_url"]: f"{explorer_url}/address/{vulnerable_contract_address}#code" if vulnerable_contract_address else "N/A",
            self.constants.POC_TEMPLATE_REPLACEMENTS["post_mortem_url"]: post_mortem_url if post_mortem_url else "N/A",
            self.constants.POC_TEMPLATE_REPLACEMENTS["twitter_guy_url"]: twitter_guy_url if twitter_guy_url else "N/A",
            self.constants.POC_TEMPLATE_REPLACEMENTS["hacking_god_url"]: hacking_god_url if hacking_god_url else "N/A",
            self.constants.POC_TEMPLATE_REPLACEMENTS["exploit_script_name"]: name_part,
            self.constants.POC_TEMPLATE_REPLACEMENTS["network_name"]: selected_network,
            self.constants.POC_TEMPLATE_REPLACEMENTS["base_test_path"]: "../basetest.sol",
        }
        
        # Replace template placeholders
        modified_content = self._replace_placeholders(template_content, replacements)

        # Replace exploit() with testExploit() for forge test compatibility
        modified_content = modified_content.replace("function exploit()", "function testExploit()")
        
        # Write to new file
        with open(new_file_path, "w") as new_file:
            new_file.write(modified_content)
        
        print(f"Created POC file: {new_file_path}")
    
    def _replace_placeholders(self, content: str, replacements: dict) -> str:
        """Replace placeholders in template content"""
        for placeholder, replacement in replacements.items():
            content = content.replace(placeholder, replacement)
        return content


class GitManager:
    """Manages Git-related operations"""
    
    def __init__(self, constants):
        self.constants = constants
    
    def is_git_command_available(self):
        """Check if git command is available"""
        try:
            subprocess.check_output(["git", "--version"])
            return True
        except (FileNotFoundError, subprocess.CalledProcessError):
            return False
    
    def get_uncommitted_sol_files(self):
        """Get list of uncommitted .sol files"""
        if not self.is_git_command_available():
            print("Git command is not available. Skipping uncommitted file retrieval.")
            return []
        
        command = f"git ls-files --others --exclude-standard {self.constants.SRC_TEST_DIR}/**/*.sol"
        output = subprocess.check_output(command, shell=True, text=True)
        uncommitted_files = output.strip().split("\n")
        return uncommitted_files
    
    def get_recently_committed_sol_files(self) -> list:
        """Get list of recently committed .sol files"""
        if not self.is_git_command_available():
            print("Git command is not available. Skipping recently committed file retrieval.")
            return []
        
        command = f"git diff --name-only HEAD~1 HEAD {self.constants.SRC_TEST_DIR}/**/*.sol"
        output = subprocess.check_output(command, shell=True, text=True)
        recently_committed_files = output.strip().split("\n")
        return recently_committed_files


######################
# MAIN SCRIPT
######################

def main():
    """Main entry point for the script"""
    library = DefiHackLibrary()
    
    rpc_endpoints = library.config_manager.parse_foundry_toml()
    selected_network, rpc_endpoints = library.select_network()
    
    if selected_network is None:
        return
    
    # Ask user if they want to add a new entry manually first
    if input("Do you want to add a new incident entry manually? (yes/no): ").lower() == 'yes':
        library.add_new_entry(selected_network)
    
    # Then, ask about processing existing .sol files
    if input(f"Do you want to check for .sol files in '{library.constants.SRC_TEST_DIR}' missing {library.constants.README_PATH} entries? (yes/no): ").lower() == 'yes':
        library.process_existing_files()
    
    print("\nScript finished.")

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--test":
        # Remove the test argument and run tests
        sys.argv.pop(1)
        unittest.main()
    else:
        # Run the main script
        main()