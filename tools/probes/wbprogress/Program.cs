/* Probe: a hidden WinForms WebBrowser (as on Storyline's start page) navigates to argv[0] and logs its events to C:\users\Public\wbprogress.log; stock Wine never logs ProgressChanged, patch 0015 logs 10000/10000 when a download completes. Build: dotnet publish -c Release -r win-x64 --self-contained false -o out */
using System;
using System.IO;
using System.Windows.Forms;

static class Program
{
    static StreamWriter log;
    static void L(string s) { log.WriteLine($"{DateTime.Now:HH:mm:ss.fff} {s}"); log.Flush(); }

    [STAThread]
    static void Main(string[] args)
    {
        log = new StreamWriter(@"C:\users\Public\wbprogress.log", false);
        string url = args.Length > 0 ? args[0] : "about:blank";
        var form = new Form { Width = 900, Height = 600, Text = "wbprogress " + url };
        var wb = new WebBrowser { Dock = DockStyle.Fill, Visible = args.Length > 1 && args[1] == "visible" };
        form.Controls.Add(wb);
        wb.ProgressChanged += (s, e) => L($"ProgressChanged {e.CurrentProgress}/{e.MaximumProgress}");
        wb.Navigating += (s, e) => L($"Navigating {e.Url}");
        wb.Navigated += (s, e) => L($"Navigated {e.Url}");
        wb.DocumentCompleted += (s, e) => { L($"DocumentCompleted {e.Url} title='{wb.DocumentTitle}' readyState={wb.ReadyState}"); };
        var t = new Timer { Interval = 25000 };
        t.Tick += (s, e) => { L($"timeout: readyState={wb.ReadyState} visible={wb.Visible}"); form.Close(); };
        form.Shown += (s, e) =>
        {
            try { L("navigate " + url); wb.Navigate(url); } catch (Exception ex) { L("navigate threw " + ex); }
            t.Start();
        };
        try { Application.Run(form); } catch (Exception ex) { L("run threw " + ex); }
        L("exit");
    }
}
