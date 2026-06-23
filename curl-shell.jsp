<%@ page import="java.io.*, java.util.*" %>
<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" trimDirectiveWhitespaces="true" %>
<%!
    /* ── HTML escaping (no external deps) ─────────────────────────── */
    private static String h(String s) {
        if (s == null) return "";
        return s.replace("&","&amp;").replace("<","&lt;").replace(">","&gt;")
                .replace("\"","&quot;").replace("'","&#39;");
    }

    /**
     * Runs a curl command.
     * Returns String[3]: { exitCode, stdout, stderr }
     * Compatible with JSP 1.x/2.x/3.x and all servlet containers.
     */
    private String[] runCurl(String[] cmd) throws Exception {
        Process process = null;
        final StringBuilder stdout = new StringBuilder();
        final StringBuilder stderr = new StringBuilder();
        int exitCode = -1;

        try {
            ProcessBuilder pb = new ProcessBuilder(cmd);
            pb.environment().put("LANG", "en_US.UTF-8");
            process = pb.start();

            // Drain both streams concurrently — blocking on one will deadlock the other
            final InputStream outStream = process.getInputStream();
            final InputStream errStream = process.getErrorStream();

            Thread outThread = new Thread(() -> {
                try (BufferedReader r = new BufferedReader(
                        new InputStreamReader(outStream, "UTF-8"))) {
                    String line;
                    while ((line = r.readLine()) != null) stdout.append(line).append("\n");
                } catch (IOException e) {
                    stderr.append("[stdout drain error: ").append(e.getMessage()).append("]");
                }
            });
            Thread errThread = new Thread(() -> {
                try (BufferedReader r = new BufferedReader(
                        new InputStreamReader(errStream, "UTF-8"))) {
                    String line;
                    while ((line = r.readLine()) != null) stderr.append(line).append("\n");
                } catch (IOException e) {
                    stderr.append("[stderr drain error: ").append(e.getMessage()).append("]");
                }
            });
            outThread.start();
            errThread.start();

            // Timeout loop (waitFor(long,TimeUnit) needs Java 8+ / Servlet 3.1+
            // — this spin-wait works everywhere including very old containers)
            long deadline = System.currentTimeMillis() + 15_000L;
            boolean done = false;
            while (!done && System.currentTimeMillis() < deadline) {
                try { exitCode = process.exitValue(); done = true; }
                catch (IllegalThreadStateException e) { Thread.sleep(50); }
            }
            if (!done) {
                process.destroy();
                stderr.append("[TIMEOUT: process killed after 15 s]");
                exitCode = -2;
            }

            outThread.join(3000);
            errThread.join(3000);

        } finally {
            if (process != null) {
                // Close all streams explicitly — required on some older JVMs
                try { process.getInputStream().close();  } catch (IOException ignored) {}
                try { process.getErrorStream().close();  } catch (IOException ignored) {}
                try { process.getOutputStream().close(); } catch (IOException ignored) {}
                process.destroy();
            }
        }

        return new String[]{ String.valueOf(exitCode), stdout.toString(), stderr.toString() };
    }
%>
<%
    /* ── Configuration ──────────────────────────────────────────────── */
    String targetUrl = "https://webhook.site/dee0c407-1982-4e24-a388-0f3e32637cca";   // ← change this

    String[] cmd = new String[]{
        "curl",
        "--silent",            // suppress progress meter
        "--show-error",        // but show error messages on stderr
        "--fail",              // exit non-zero on HTTP 4xx / 5xx
        "--location",          // follow redirects
        "--max-time",   "10",  // hard total timeout (seconds)
        "--connect-timeout", "5",
        "--user-agent", "JSP-curl/1.0",
        "--header",     "Accept: application/json",
        // "--header", "Authorization: Bearer YOUR_TOKEN",
        // "--request", "POST",
        // "--data",   "{\"key\":\"value\"}",
        targetUrl
    };
    /* ─────────────────────────────────────────────────────────────── */

    String   exitCodeStr = "-1";
    String   stdoutStr   = "";
    String   stderrStr   = "";
    String   javaError   = null;

    try {
        String[] result = runCurl(cmd);
        exitCodeStr = result[0];
        stdoutStr   = result[1];
        stderrStr   = result[2];
    } catch (Exception ex) {
        javaError = ex.getClass().getName() + ": " + ex.getMessage();
    }

    int     exitCode = Integer.parseInt(exitCodeStr);
    boolean success  = (exitCode == 0);
%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>curl result</title>
    <style>
        body { font-family: monospace; padding: 1rem 2rem; max-width: 900px; }
        pre  { background:#f4f4f4; padding:1rem; border-radius:4px;
               overflow-x:auto; white-space:pre-wrap; word-break:break-all; }
        .ok  { color:#256525; } .err { color:#cc0000; }
        table { border-collapse:collapse; margin-bottom:1rem; }
        td { padding:2px 12px 2px 0; }
    </style>
</head>
<body>

<h2>curl → <code><%=h(targetUrl)%></code></h2>

<table>
  <tr><td>Exit code</td>
      <td class="<%=success?"ok":"err"%>"><strong><%=exitCode%></strong>
      <%=success ? "✓ success" : "✗ failure"%></td></tr>
  <tr><td>curl command</td>
      <td><code><%=h(java.util.Arrays.toString(cmd))%></code></td></tr>
</table>

<% if (javaError != null) { %>
  <h3 class="err">Java / JVM error (curl never ran)</h3>
  <pre class="err"><%=h(javaError)%></pre>
<% } %>

<% if (!stderrStr.isEmpty()) { %>
  <h3 class="err">curl stderr</h3>
  <pre class="err"><%=h(stderrStr)%></pre>
<% } %>

<% if (!stdoutStr.isEmpty()) { %>
  <h3 class="<%=success?"ok":"err"%>">Response body</h3>
  <pre><%=h(stdoutStr)%></pre>
<% } else if (success) { %>
  <p class="ok">(Empty response body — request succeeded with exit 0)</p>
<% } %>

</body>
</html>
