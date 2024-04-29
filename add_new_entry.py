import re
from datetime import datetime
import os
import toml

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
        "blast":"https://blastscan.io",
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
        # Display the available networks
        print("Available networks:")
        for i, network in enumerate(rpc_endpoints, start=1):
            print(f"{i}. {network}")
        print(f"{len(rpc_endpoints) + 1}. Add a new network")

        # Prompt the user to select a network
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

def add_new_entry():
    # Read the rpc_endpoints from foundry.toml
    rpc_endpoints = parse_foundry_toml()

    # Select the network
    selected_network, rpc_endpoints = select_network(rpc_endpoints)

    # Update foundry.toml with the selected network
    # update_foundry_toml(rpc_endpoints)
    print("NOTE do not give explorer urls for any address asked in the script,script automatically adds it")
    file_name = input("Enter the file name (e.g., Example_exp.sol): ")
    timestamp_str = input(
        "Enter the timestamp string (e.g., Mar-21-2024 02:51:33 PM): "
    )
    lost_amount = input("Enter the lost amount: ")
    additional_details = input("Enter additional details: ")
    link_reference = input("Enter the link reference: ")

    attacker_address = input("Enter the attacker's address: ")
    attack_contract_address = input("Enter the attack contract address: ")
    vulnerable_contract_address = input("Enter the vulnerable contract address: ")
    attack_tx_hash = input("Enter the attack transaction hash: ")
    post_mortem_url = input("Enter the post-mortem URL: ")
    twitter_guy_url = input("Enter the Twitter guy URL: ")
    hacking_god_url = input("Enter the hacking god URL: ")

    create_poc_file = input("Do you want to create a new Solidity file for this POC? (yes/no): ")

    if create_poc_file.lower() == "yes":
        create_poc_solidity_file(file_name, lost_amount, attacker_address, attack_contract_address,
                                 vulnerable_contract_address, attack_tx_hash,
                                 post_mortem_url, twitter_guy_url, hacking_god_url, selected_network)

    with open("README.md", "r") as file:
        content = file.read()

    # Convert the timestamp string to a datetime object
    timestamp = datetime.strptime(timestamp_str, "%b-%d-%Y %I:%M:%S %p")

    # Format the date as desired
    formatted_date = timestamp.strftime("%Y%m%d")

    # Extract the name from the file name
    name = file_name.split("_")[0]

    # Generate the new entry
    new_entry = f"""
### {formatted_date} {name} - {additional_details}

### Lost: {lost_amount}


```sh
forge test --contracts ./src/test/{file_name} -vvv
```
#### Contract
[{file_name}](src/test/{file_name})
### Link reference

{link_reference}

---

"""

    # Find the position to insert the new entry
    insert_pos = re.search(
        r"### List of DeFi Hacks & POCs(.*?)(?=###|\Z)", content, re.DOTALL
    ).end()

    # Insert the new entry
    updated_content = content[:insert_pos] + "\n\n" + new_entry + content[insert_pos:]

    # Update the table of contents
    toc_entry = f"[{formatted_date} {name}](#{formatted_date.lower()}-{name.lower()}---{additional_details.lower().replace(' ', '-')})"
    toc_insert_pos = re.search(r"## List of Past DeFi Incidents", updated_content).end()
    updated_content = (
        updated_content[:toc_insert_pos] + "\n" + toc_entry + updated_content[toc_insert_pos:]
    )

    with open("README.md", "w") as file:
        file.write(updated_content)

def replace_placeholders(content, replacements):
    for placeholder, replacement in replacements.items():
        content = content.replace(placeholder, replacement)
    return content

def create_poc_solidity_file(file_name, lost_amount, attacker_address, attack_contract_address,
                             vulnerable_contract_address, attack_tx_hash, post_mortem_url,
                             twitter_guy_url, hacking_god_url, selected_network):
    new_file_name = file_name.replace("_exp.sol", "") + "_exp.sol"
    new_file_path = os.path.join("src", "test", new_file_name)

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
        "19_494_655": "1234567",
        "//implement exploit code here": "// Implement exploit code here",
        "//Try to log balances after exploit here to show the POC works,example is below": "// Log balances after exploit",
        "address(this).balance": "address(this).balance"
    }

    modified_content = replace_placeholders(template_content, replacements)

    with open(new_file_path, "w") as new_file:
        new_file.write(modified_content)

add_new_entry()
