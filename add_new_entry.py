from datetime import datetime
import re
import os
import toml
import subprocess

def parse_foundry_toml():
    with open("foundry.toml", "r") as toml_file:
        config = toml.load(toml_file)
        rpc_endpoints = config.get("rpc_endpoints", {})
    return rpc_endpoints

def update_foundry_toml(rpc_endpoints):
    with open("foundry.toml", "r") as toml_file:
        config = toml.load(toml_file)

    config["rpc_endpoints"] = rpc_endpoints

    with open("foundry.toml", "w") as toml_file:
        toml.dump(config, toml_file)

def set_explorer_url(network):
    explorer_urls = {
        "mainnet": "https://etherscan.io",
        "blast": "https://blastscan.io",
        "optimism": "https://optimistic.etherscan.io",
        "fantom": "https://ftmscan.com",
        "arbitrum": "https://arbiscan.io",
        "bsc": "https://bscscan.com",
        "moonriver": "https://moonriver.moonscan.io",
        "gnosis": "https://gnosisscan.io",
        "avalanche": "https://snowtrace.io",
        "polygon": "https://polygonscan.com",
        "celo": "https://celoscan.io",
        "base": "https://basescan.org"
    }
    return explorer_urls.get(network, "")

def select_network(rpc_endpoints):
    while True:
        print("Available networks:")
        for i, network in enumerate(rpc_endpoints, start=1):
            print(f"{i}. {network}")
        print(f"{len(rpc_endpoints) + 1}. Add a new network")

        choice = input("Enter the number corresponding to the network you want to use: ")

        try:
            choice = int(choice)
            if 1 <= choice <= len(rpc_endpoints):
                selected_network = list(rpc_endpoints.keys())[choice - 1]
                break
            elif choice == len(rpc_endpoints) + 1:
                new_network_name = input("Enter the name of the new network: ")
                new_network_url = input("Enter the RPC URL of the new network: ")
                rpc_endpoints[new_network_name] = new_network_url
                selected_network = new_network_name
                break
            else:
                print("Invalid choice. Please try again.")
        except ValueError:
            print("Invalid input. Please enter a valid number.")

    return selected_network, rpc_endpoints

def get_timestamp_from_str(timestampstr):
    if timestampstr:
        return datetime.strptime(timestampstr, "%b-%d-%Y %I:%M:%S %p")
    else:
        return datetime.now()

def get_sol_file_info():
    print("NOTE: The script automatically adds explorer URLs for any address provided.")
    file_name = input("Enter the file name (e.g., Example_exp.sol): ")
    timestamp_str = input("Enter the timestamp string (e.g., Mar-21-2024 02:51:33 PM) or leave empty to use current timestamp: ")
    lost_amount = input("Enter the lost amount: ")
    additional_details = input("Enter additional details: ")
    link_reference = input("Enter the link reference: ")
    return file_name, timestamp_str, lost_amount, additional_details, link_reference

def get_sol_file_extra_info():
    attacker_address = input("Enter the attacker's address: ")
    attack_contract_address = input("Enter the attack contract address: ")
    vulnerable_contract_address = input("Enter the vulnerable contract address: ")
    attack_tx_hash = input("Enter the attack transaction hash: ")
    post_mortem_url = input("Enter the post-mortem URL: ")
    twitter_guy_url = input("Enter the Twitter guy URL: ")
    hacking_god_url = input("Enter the hacking god URL: ")
    return attacker_address, attack_contract_address, vulnerable_contract_address, attack_tx_hash, post_mortem_url, twitter_guy_url, hacking_god_url

def add_new_entry(selected_network):
    file_name, timestamp_str, lost_amount, additional_details, link_reference = get_sol_file_info()

    create_poc_file = input("Do you want to create a new Solidity file for this POC? (yes/no): ")

    if create_poc_file.lower() == "yes":
        attacker_address, attack_contract_address, vulnerable_contract_address, attack_tx_hash, post_mortem_url, twitter_guy_url, hacking_god_url = get_sol_file_extra_info()
        create_poc_solidity_file(file_name, lost_amount, attacker_address, attack_contract_address,
                                 vulnerable_contract_address, attack_tx_hash,
                                 post_mortem_url, twitter_guy_url, hacking_god_url, selected_network, timestamp_str)

    with open("README.md", "r") as file:
        content = file.read()
    timestamp = get_timestamp_from_str(timestamp_str)
    formatted_date = timestamp.strftime("%Y%m%d")
    name = file_name.split("_")[0]

    new_entry = generate_new_entry(formatted_date, name, additional_details, lost_amount, file_name, link_reference)

    updated_content = insert_new_entry(content, new_entry)
    updated_content = update_table_of_contents(updated_content, formatted_date, name, additional_details)

    with open("README.md", "w") as file:
        file.write(updated_content)

def generate_new_entry(formatted_date, name, additional_details, lost_amount, file_name, link_reference):
    return f"""
### {formatted_date} {name} - {additional_details}

### Lost: {lost_amount}


```sh
forge test --contracts ./src/test/{formatted_date[:4]}-{formatted_date[4:6]}/{file_name} -vvv
```
#### Contract
[{file_name}](src/test/{formatted_date[:4]}-{formatted_date[4:6]}/{file_name})
### Link reference

{link_reference}

---

"""

def insert_new_entry(content, new_entry):
    insert_pos = re.search(r"### List of DeFi Hacks & POCs(.*?)(?=###|\Z)", content, re.DOTALL).end()
    return content[:insert_pos] + "\n\n" + new_entry + content[insert_pos:]

def update_table_of_contents(content, formatted_date, name, additional_details):
    toc_entry = f"[{formatted_date} {name}](#{formatted_date.lower()}-{name.lower()}---{additional_details.lower().replace(' ', '-')})"
    toc_insert_pos = re.search(r"## List of Past DeFi Incidents", content).end()
    return content[:toc_insert_pos] + "\n" + toc_entry + content[toc_insert_pos:]

def replace_placeholders(content, replacements):
    for placeholder, replacement in replacements.items():
        content = content.replace(placeholder, replacement)
    return content

def create_poc_solidity_file(file_name, lost_amount, attacker_address, attack_contract_address,
                             vulnerable_contract_address, attack_tx_hash, post_mortem_url,
                             twitter_guy_url, hacking_god_url, selected_network, timestamp_str):

    timestamp = get_timestamp_from_str(timestamp_str)
    formatted_date = timestamp.strftime("%Y-%m")
    new_file_name = file_name.replace("_exp.sol", "") + "_exp.sol"
    new_file_path = os.path.join("src", "test", formatted_date, new_file_name)

    os.makedirs(os.path.dirname(new_file_path), exist_ok=True)

    with open("script/Exploit-template_new.sol", "r") as template_file:
        template_content = template_file.read()

    explorer_url = set_explorer_url(selected_network)

    replacements = {
        "~999M US$": lost_amount,
        "0xcafebabe": f"{explorer_url}/address/{attacker_address}",
        "attackcontractaddrhere": f"{explorer_url}/address/{attack_contract_address}",
        "vulcontractaddrhere": f"{explorer_url}/address/{vulnerable_contract_address}",
        "0x123456789": f"{explorer_url}/tx/{attack_tx_hash}",
        "https://etherscan.io/address/0xdeadbeef#code": f"{explorer_url}/address/{vulnerable_contract_address}#code",
        "postmortemurlhere": post_mortem_url,
        "twitterguyhere": twitter_guy_url,
        "hackinggodhere": hacking_god_url,
        "ExploitScript": file_name.split("_")[0],
        "mainnet": selected_network,
    }

    modified_content = replace_placeholders(template_content, replacements)

    with open(new_file_path, "w") as new_file:
        new_file.write(modified_content)

def get_uncommitted_sol_files():
    command = "git ls-files --others --exclude-standard src/test/**/*.sol"
    output = subprocess.check_output(command, shell=True, text=True)
    uncommitted_files = output.strip().split("\n")
    return uncommitted_files

def get_recently_committed_sol_files():
    command = "git diff --name-only HEAD~1 HEAD src/test/**/*.sol"
    output = subprocess.check_output(command, shell=True, text=True)
    recently_committed_files = output.strip().split("\n")
    return recently_committed_files

def check_readme_entry(file_path):
    with open("README.md", "r") as file:
        content = file.read()
    file_name = os.path.basename(file_path)
    return file_name not in content

def process_sol_files(sol_files):
    for file_path in sol_files:
        if check_readme_entry(file_path):
            print(f"No README entry found for {file_path}. Adding new entry...")
            add_new_entry_from_file(file_path)
        else:
            print(f"README entry already exists for {file_path}. Skipping...")

def add_new_entry_from_file(file_path):
    file_name = os.path.basename(file_path)
    timestamp_str = input(f"Enter the timestamp string for {file_name} (e.g., Mar-21-2024 02:51:33 PM) or leave empty to use current timestamp: ")
    lost_amount = input(f"Enter the lost amount for {file_name}: ")
    additional_details = input(f"Enter additional details for {file_name}: ")
    link_reference = input(f"Enter the link reference for {file_name}: ")

    with open("README.md", "r") as file:
        content = file.read()

    timestamp = get_timestamp_from_str(timestamp_str)
    formatted_date = timestamp.strftime("%Y%m%d")
    name = file_name.split("_")[0]

    new_entry = generate_new_entry(formatted_date, name, additional_details, lost_amount, file_name, link_reference)

    updated_content = insert_new_entry(content, new_entry)
    updated_content = update_table_of_contents(updated_content, formatted_date, name, additional_details)

    with open("README.md", "w") as file:
        file.write(updated_content)

def main():
    rpc_endpoints = parse_foundry_toml()
    selected_network, rpc_endpoints = select_network(rpc_endpoints)

    add_new_entry(selected_network)

    uncommitted_sol_files = get_uncommitted_sol_files()
    recently_committed_sol_files = get_recently_committed_sol_files()

    process_sol_files(uncommitted_sol_files)
    process_sol_files(recently_committed_sol_files)

if __name__ == "__main__":
    main()