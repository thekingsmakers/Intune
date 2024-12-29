import os
import re
from pathlib import Path
import base64
import json
from urllib.parse import quote
import requests

def get_script_sections():
    """Get all PowerShell scripts from the repository and their metadata."""
    scripts = []
    
    # Get list of files that were modified in the last commit
    repo = os.environ.get('GITHUB_REPOSITORY', 'thekingsmakers/IntuneUsefullScript')
    token = os.environ.get('GITHUB_TOKEN')
    headers = {'Authorization': f'token {token}'} if token else {}
    
    # Get repository contents
    api_url = f'https://api.github.com/repos/{repo}/git/trees/main?recursive=1'
    response = requests.get(api_url, headers=headers)
    if response.status_code == 200:
        tree = response.json().get('tree', [])
        
        for item in tree:
            if item['path'].endswith('.ps1'):
                # Get script content to extract description
                script_url = f'https://api.github.com/repos/{repo}/contents/{item["path"]}'
                script_response = requests.get(script_url, headers=headers)
                
                if script_response.status_code == 200:
                    content = script_response.json()
                    try:
                        script_content = base64.b64decode(content['content']).decode('utf-8')
                        # Try to extract description from comments
                        description = extract_description(script_content)
                        
                        scripts.append({
                            'name': Path(item['path']).stem,
                            'path': item['path'],
                            'description': description,
                            'raw_url': f'https://raw.githubusercontent.com/{repo}/main/{quote(item["path"])}'
                        })
                    except Exception as e:
                        print(f"Error processing {item['path']}: {e}")
    
    return scripts

def extract_description(content):
    """Extract description from script comments."""
    # Look for comment block or first comment line
    comment_block = re.search(r'<#(.*?)#>', content, re.DOTALL)
    if comment_block:
        return comment_block.group(1).strip()
    
    first_comment = re.search(r'#\s*(.+)', content)
    if first_comment:
        return first_comment.group(1).strip()
    
    return "A useful PowerShell script for Intune management"

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
    """Update index.html with new script sections."""
    scripts = get_script_sections()
    
    # Read current index.html
    with open('index.html', 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Find the container div
    container_match = re.search(r'(<div class="container".*?>)(.*?)(</div>)\s*</body>', content, re.DOTALL)
    if container_match:
        # Keep the existing content and add new sections
        container_content = container_match.group(2)
        
        # Remove old script sections
        container_content = re.sub(r'<section class="readme">.*?</section>', '', container_content, flags=re.DOTALL)
        
        # Add new script sections
        new_sections = '\n'.join(generate_section_html(script) for script in scripts)
        
        # Update the content
        new_content = content.replace(container_match.group(0), 
                                    f'{container_match.group(1)}{container_content}\n{new_sections}\n{container_match.group(3)}</body>')
        
        # Update copy function in JavaScript
        copy_function = '''
        <script>
        function copyCommand(scriptName) {
            const command = document.getElementById(`scriptCommand_${scriptName}`).innerText;
            navigator.clipboard.writeText(command).then(() => {
                alert("Command copied to clipboard!");
            }).catch(err => {
                console.error('Failed to copy: ', err);
            });
        }
        </script>
        '''
        
        # Add copy function if not present
        if 'function copyCommand' not in new_content:
            new_content = new_content.replace('</body>', f'{copy_function}</body>')
        
        # Write updated content
        with open('index.html', 'w', encoding='utf-8') as f:
            f.write(new_content)

if __name__ == '__main__':
    update_index_html()
