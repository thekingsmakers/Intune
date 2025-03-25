using System;
using System.Windows.Forms;

namespace SetupGUI
{
    static class Program
    {
        [STAThread]
        static void Main()
        {
            try
            {
                Application.SetHighDpiMode(HighDpiMode.SystemAware);
                Application.EnableVisualStyles();
                Application.SetCompatibleTextRenderingDefault(false);
                
                // Ensure running as administrator
                if (!System.Security.Principal.WindowsIdentity.GetCurrent().Owner.IsWellKnown(
                    System.Security.Principal.WellKnownSidType.BuiltinAdministratorsSid))
                {
                    MessageBox.Show("This application requires administrative privileges.", 
                        "Administrator Rights Required", 
                        MessageBoxButtons.OK, 
                        MessageBoxIcon.Warning);
                    return;
                }

                Application.Run(new MainForm());
            }
            catch (Exception ex)
            {
                MessageBox.Show($"An error occurred: {ex.Message}\n\nStack Trace:\n{ex.StackTrace}",
                    "Error",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error);
            }
        }
    }
}