import os
import re
from pathlib import Path
import base64
import json
from urllib.parse import quote
import requests
from bs4 import BeautifulSoup

def get_script_sections():
    """Get all PowerShell scripts from the repository and their metadata."""
    scripts = []
    repo = os.environ.get('GITHUB_REPOSITORY', 'thekingsmakers/Intune')
    token = os.environ.get('GITHUB_TOKEN')
    headers = {'Authorization': f'token {token}'} if token else {}
    
    print(f"Fetching scripts from repository: {repo}")
    
    api_url = f'https://api.github.com/repos/{repo}/contents'
    response = requests.get(api_url, headers=headers)
    
    def process_contents(contents):
        for item in contents:
            if item['type'] == 'file' and item['name'].endswith('.ps1'):
                print(f"Processing PowerShell script: {item['path']}")
                try:
                    script_response = requests.get(item['download_url'])
                    script_content = script_response.text
                    description = extract_description(script_content)
                    
                    scripts.append({
                        'name': Path(item['name']).stem,
                        'path': item['path'],
                        'description': description,
                        'raw_url': item['download_url']
                    })
                    print(f"Successfully processed: {item['path']}")
                except Exception as e:
                    print(f"Error processing {item['path']}: {e}")
            elif item['type'] == 'dir':
                subdir_response = requests.get(f"{api_url}/{item['name']}", headers=headers)
                if subdir_response.status_code == 200:
                    process_contents(subdir_response.json())

    if response.status_code == 200:
        process_contents(response.json())
    else:
        print(f"Failed to fetch repository contents. Status code: {response.status_code}")
        print(f"Response: {response.text}")
    
    return scripts

def extract_description(content):
    """Extract description from script comments."""
    comment_block = re.search(r'<#(.*?)#>', content, re.DOTALL)
    if comment_block:
        return comment_block.group(1).strip()
    
    first_comment = re.search(r'#\s*(.+)', content)
    if first_comment:
        return first_comment.group(1).strip()
    
    return "A PowerShell script for Intune management"

def generate_section_html(script):
    """Generate HTML section for a script."""
    return f'''
        <section class="readme">
            <h2>{script['name'].replace('-', ' ').title()}</h2>
            <p>{script['description']}</p>
            <p>Run the following PowerShell command to execute this script:</p>
            <pre id="scriptCommand_{script['name']}">iwr "{script['raw_url']}" | iex</pre>
            <button class="copy-btn" onclick="copyCommand('{script['name']}')">Copy Command</button>
        </section>
    '''

def update_index_html():
    """Update index.html with script sections."""
    print("Starting index.html update process")
    
    # Read the current index.html
    try:
        with open('index.html', 'r', encoding='utf-8') as f:
            soup = BeautifulSoup(f, 'html.parser')
            print("Successfully read index.html")
    except Exception as e:
        print(f"Error reading index.html: {e}")
        return

    # Get scripts
    scripts = get_script_sections()
    print(f"Found {len(scripts)} PowerShell scripts")

    # Find the container div
    container = soup.find('div', class_='container')
    if container:
        # Remove existing readme sections
        for section in container.find_all('section', class_='readme'):
            section.decompose()
        
        # Add new script sections
        for script in scripts:
            section_html = generate_section_html(script)
            container.append(BeautifulSoup(section_html, 'html.parser'))
        
        # Save the updated file
        try:
            with open('index.html', 'w', encoding='utf-8') as f:
                f.write(str(soup))
            print("Successfully updated index.html")
        except Exception as e:
            print(f"Error writing index.html: {e}")
    else:
        print("Could not find container div in index.html")

if __name__ == '__main__':
    update_index_html()
