using System;
using System.Windows.Forms;
using System.Xml;
using System.IO;

namespace SetupGUI
{
    public partial class MainForm : Form
    {
        private string configPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, @"..\Deployment\Config\deploy-config.xml");
        private XmlDocument xmlDoc;

        public MainForm()
        {
            InitializeComponent();
            LoadConfiguration();
        }

        private void InitializeComponent()
        {
            this.Text = "Windows Deployment Configuration";
            this.Size = new System.Drawing.Size(600, 600);
            this.StartPosition = FormStartPosition.CenterScreen;

            // Create tab control
            TabControl tabControl = new TabControl();
            tabControl.Dock = DockStyle.Fill;

            // System Tab
            TabPage systemTab = new TabPage("System");
            AddSystemControls(systemTab);
            tabControl.TabPages.Add(systemTab);

            // Network Tab
            TabPage networkTab = new TabPage("Network");
            AddNetworkControls(networkTab);
            tabControl.TabPages.Add(networkTab);

            // Domain Tab
            TabPage domainTab = new TabPage("Domain");
            AddDomainControls(domainTab);
            tabControl.TabPages.Add(domainTab);

            // Features Tab
            TabPage featuresTab = new TabPage("Features");
            AddFeaturesControls(featuresTab);
            tabControl.TabPages.Add(featuresTab);

            // Save Button
            Button saveButton = new Button();
            saveButton.Text = "Save Configuration";
            saveButton.Dock = DockStyle.Bottom;
            saveButton.Click += SaveButton_Click;

            this.Controls.AddRange(new Control[] { tabControl, saveButton });
        }

        private void LoadConfiguration()
        {
            try
            {
                xmlDoc = new XmlDocument();
                if (File.Exists(configPath))
                {
                    xmlDoc.Load(configPath);
                }
                else
                {
                    xmlDoc.LoadXml(@"<?xml version=""1.0"" encoding=""utf-8""?>
                        <Deployment>
                            <Software><Package></Package></Software>
                            <Hostname></Hostname>
                            <Network>
                                <SSID></SSID>
                                <Password></Password>
                            </Network>
                            <WindowsActivation>
                                <ProductKey></ProductKey>
                            </WindowsActivation>
                            <Features><Feature></Feature></Features>
                            <Domain>
                                <JoinDomain>false</JoinDomain>
                                <DomainName></DomainName>
                                <DomainUser></DomainUser>
                                <DomainPassword></DomainPassword>
                            </Domain>
                            <RestartAfter>true</RestartAfter>
                        </Deployment>");
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Error loading configuration: {ex.Message}", "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        private void AddSystemControls(TabPage tab)
        {
            TableLayoutPanel panel = new TableLayoutPanel();
            panel.Dock = DockStyle.Fill;
            panel.ColumnCount = 2;
            panel.RowCount = 2;
            panel.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 30F));
            panel.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 70F));

            // Hostname
            panel.Controls.Add(new Label { Text = "Hostname:", Dock = DockStyle.Fill }, 0, 0);
            TextBox hostnameBox = new TextBox { Dock = DockStyle.Fill };
            hostnameBox.Text = GetNodeValue("/Deployment/Hostname");
            hostnameBox.Tag = "hostname";
            panel.Controls.Add(hostnameBox, 1, 0);

            // Windows Key
            panel.Controls.Add(new Label { Text = "Windows Key:", Dock = DockStyle.Fill }, 0, 1);
            TextBox keyBox = new TextBox { Dock = DockStyle.Fill };
            keyBox.Text = GetNodeValue("/Deployment/WindowsActivation/ProductKey");
            keyBox.Tag = "windows-key";
            panel.Controls.Add(keyBox, 1, 1);

            tab.Controls.Add(panel);
        }

        private void AddNetworkControls(TabPage tab)
        {
            TableLayoutPanel panel = new TableLayoutPanel();
            panel.Dock = DockStyle.Fill;
            panel.ColumnCount = 2;
            panel.RowCount = 2;
            panel.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 30F));
            panel.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 70F));

            // WiFi SSID
            panel.Controls.Add(new Label { Text = "WiFi SSID:", Dock = DockStyle.Fill }, 0, 0);
            TextBox ssidBox = new TextBox { Dock = DockStyle.Fill };
            ssidBox.Text = GetNodeValue("/Deployment/Network/SSID");
            ssidBox.Tag = "wifi-ssid";
            panel.Controls.Add(ssidBox, 1, 0);

            // WiFi Password
            panel.Controls.Add(new Label { Text = "WiFi Password:", Dock = DockStyle.Fill }, 0, 1);
            TextBox passBox = new TextBox { Dock = DockStyle.Fill, UseSystemPasswordChar = true };
            passBox.Text = GetNodeValue("/Deployment/Network/Password");
            passBox.Tag = "wifi-password";
            panel.Controls.Add(passBox, 1, 1);

            tab.Controls.Add(panel);
        }

        private void AddDomainControls(TabPage tab)
        {
            TableLayoutPanel panel = new TableLayoutPanel();
            panel.Dock = DockStyle.Fill;
            panel.ColumnCount = 2;
            panel.RowCount = 4;
            panel.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 30F));
            panel.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 70F));

            // Join Domain Checkbox
            CheckBox joinDomainBox = new CheckBox { Text = "Join Domain", Dock = DockStyle.Fill };
            joinDomainBox.Checked = GetNodeValue("/Deployment/Domain/JoinDomain") == "true";
            joinDomainBox.Tag = "join-domain";
            panel.Controls.Add(joinDomainBox, 0, 0);
            panel.SetColumnSpan(joinDomainBox, 2);

            // Domain Name
            panel.Controls.Add(new Label { Text = "Domain:", Dock = DockStyle.Fill }, 0, 1);
            TextBox domainBox = new TextBox { Dock = DockStyle.Fill };
            domainBox.Text = GetNodeValue("/Deployment/Domain/DomainName");
            domainBox.Tag = "domain-name";
            panel.Controls.Add(domainBox, 1, 1);

            // Domain Username
            panel.Controls.Add(new Label { Text = "Username:", Dock = DockStyle.Fill }, 0, 2);
            TextBox userBox = new TextBox { Dock = DockStyle.Fill };
            userBox.Text = GetNodeValue("/Deployment/Domain/DomainUser");
            userBox.Tag = "domain-user";
            panel.Controls.Add(userBox, 1, 2);

            // Domain Password
            panel.Controls.Add(new Label { Text = "Password:", Dock = DockStyle.Fill }, 0, 3);
            TextBox passBox = new TextBox { Dock = DockStyle.Fill, UseSystemPasswordChar = true };
            passBox.Text = GetNodeValue("/Deployment/Domain/DomainPassword");
            passBox.Tag = "domain-pass";
            panel.Controls.Add(passBox, 1, 3);

            tab.Controls.Add(panel);
        }

        private void AddFeaturesControls(TabPage tab)
        {
            CheckedListBox featuresList = new CheckedListBox();
            featuresList.Dock = DockStyle.Fill;
            featuresList.Tag = "features";

            string[] features = new string[] {
                "TelnetClient",
                "TFTP",
                "Microsoft-Hyper-V",
                "Microsoft-Windows-Subsystem-Linux",
                "NetFx3"
            };

            featuresList.Items.AddRange(features);

            // Check features from config
            var configFeatures = GetNodeValues("/Deployment/Features/Feature");
            foreach (string feature in configFeatures)
            {
                int index = featuresList.Items.IndexOf(feature);
                if (index >= 0)
                {
                    featuresList.SetItemChecked(index, true);
                }
            }

            tab.Controls.Add(featuresList);
        }

        private string GetNodeValue(string xpath)
        {
            try
            {
                XmlNode node = xmlDoc.SelectSingleNode(xpath);
                return node?.InnerText ?? string.Empty;
            }
            catch
            {
                return string.Empty;
            }
        }

        private string[] GetNodeValues(string xpath)
        {
            try
            {
                var nodes = xmlDoc.SelectNodes(xpath);
                string[] values = new string[nodes.Count];
                for (int i = 0; i < nodes.Count; i++)
                {
                    values[i] = nodes[i].InnerText;
                }
                return values;
            }
            catch
            {
                return new string[0];
            }
        }

        private void SaveButton_Click(object sender, EventArgs e)
        {
            try
            {
                // Update XML with form values
                foreach (Control tab in this.Controls[0].Controls)
                {
                    foreach (Control control in tab.Controls)
                    {
                        if (control is TableLayoutPanel panel)
                        {
                            foreach (Control c in panel.Controls)
                            {
                                if (c is TextBox textBox)
                                {
                                    UpdateConfigValue(textBox);
                                }
                                else if (c is CheckBox checkBox && checkBox.Tag?.ToString() == "join-domain")
                                {
                                    SetNodeValue("/Deployment/Domain/JoinDomain", checkBox.Checked.ToString().ToLower());
                                }
                            }
                        }
                        else if (control is CheckedListBox featuresList && control.Tag?.ToString() == "features")
                        {
                            UpdateFeatures(featuresList);
                        }
                    }
                }

                // Save XML file
                Directory.CreateDirectory(Path.GetDirectoryName(configPath));
                xmlDoc.Save(configPath);
                MessageBox.Show("Configuration saved successfully!", "Success", MessageBoxButtons.OK, MessageBoxIcon.Information);
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Error saving configuration: {ex.Message}", "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        private void UpdateConfigValue(TextBox textBox)
        {
            if (textBox.Tag == null) return;

            string value = textBox.Text;
            switch (textBox.Tag.ToString())
            {
                case "hostname":
                    SetNodeValue("/Deployment/Hostname", value);
                    break;
                case "windows-key":
                    SetNodeValue("/Deployment/WindowsActivation/ProductKey", value);
                    break;
                case "wifi-ssid":
                    SetNodeValue("/Deployment/Network/SSID", value);
                    break;
                case "wifi-password":
                    SetNodeValue("/Deployment/Network/Password", value);
                    break;
                case "domain-name":
                    SetNodeValue("/Deployment/Domain/DomainName", value);
                    break;
                case "domain-user":
                    SetNodeValue("/Deployment/Domain/DomainUser", value);
                    break;
                case "domain-pass":
                    SetNodeValue("/Deployment/Domain/DomainPassword", value);
                    break;
            }
        }

        private void UpdateFeatures(CheckedListBox featuresList)
        {
            XmlNode featuresNode = xmlDoc.SelectSingleNode("/Deployment/Features");
            if (featuresNode != null)
            {
                featuresNode.RemoveAll();

                foreach (string feature in featuresList.CheckedItems)
                {
                    XmlElement featureElement = xmlDoc.CreateElement("Feature");
                    featureElement.InnerText = feature;
                    featuresNode.AppendChild(featureElement);
                }
            }
        }

        private void SetNodeValue(string xpath, string value)
        {
            XmlNode node = xmlDoc.SelectSingleNode(xpath);
            if (node == null)
            {
                string[] parts = xpath.Trim('/').Split('/');
                node = xmlDoc.DocumentElement;
                
                for (int i = 1; i < parts.Length; i++)
                {
                    XmlNode child = node.SelectSingleNode(parts[i]);
                    if (child == null)
                    {
                        child = xmlDoc.CreateElement(parts[i]);
                        node.AppendChild(child);
                    }
                    node = child;
                }
            }
            node.InnerText = value;
        }
    }
}