using System;
using System.Windows.Forms;
using System.Xml;
using System.Collections.Generic;
using System.Management.Automation;

namespace ImageDeployer.FeatureSelectorGUI
{
    public partial class FeatureForm : Form
    {
        private List<string> _availableFeatures = new List<string>
        {
            "TelnetClient",
            "HypervisorPlatform",
            "Microsoft-Hyper-V",
            "Containers",
            "IIS-WebServer"
        };

        public List<string> SelectedFeatures { get; private set; } = new List<string>();

        public FeatureForm()
        {
            InitializeComponent();
            LoadAvailableFeatures();
        }

        private void LoadAvailableFeatures()
        {
            clbFeatures.Items.Clear();
            foreach (var feature in _availableFeatures)
            {
                clbFeatures.Items.Add(feature, false);
            }
        }

        private void btnOK_Click(object sender, EventArgs e)
        {
            SelectedFeatures.Clear();
            foreach (var item in clbFeatures.CheckedItems)
            {
                SelectedFeatures.Add(item.ToString());
            }

            // Save to config
            SaveFeaturesToConfig();
            this.DialogResult = DialogResult.OK;
            this.Close();
        }

        private void SaveFeaturesToConfig()
        {
            try
            {
                string configPath = Path.Combine(Application.StartupPath, @"..\Automation\Config.xml");
                XmlDocument doc = new XmlDocument();
                doc.Load(configPath);

                // Remove existing features if any
                XmlNode featuresNode = doc.SelectSingleNode("//Features");
                if (featuresNode != null)
                {
                    featuresNode.ParentNode.RemoveChild(featuresNode);
                }

                // Add new features
                XmlElement features = doc.CreateElement("Features");
                foreach (var feature in SelectedFeatures)
                {
                    XmlElement featureElement = doc.CreateElement("Feature");
                    featureElement.InnerText = feature;
                    features.AppendChild(featureElement);
                }

                doc.DocumentElement.AppendChild(features);
                doc.Save(configPath);
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Error saving features: {ex.Message}", "Error",
                    MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        private void btnCancel_Click(object sender, EventArgs e)
        {
            this.DialogResult = DialogResult.Cancel;
            this.Close();
        }
    }
}