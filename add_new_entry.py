import re
from datetime import datetime


def add_new_entry():
    file_name = input("Enter the file name (e.g., Example_exp.sol): ")
    timestamp_str = input(
        "Enter the timestamp string (e.g., Mar-21-2024 02:51:33 PM): "
    )
    lost_amount = input("Enter the lost amount: ")
    additional_details = input("Enter additional details: ")
    link_reference = input("Enter the link reference: ")

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
        updated_content[:toc_insert_pos]
        + "\n"
        + toc_entry
        + updated_content[toc_insert_pos:]
    )

    with open("README.md", "w") as file:
        file.write(updated_content)


add_new_entry()
