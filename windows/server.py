from http.server import HTTPServer, BaseHTTPRequestHandler

class MyHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        client_ip = self.client_address[0]
        print(f"Client IP: {client_ip}")

        # Respond to the client
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"Hello, world!")

server_address = ('0.0.0.0', 8080)
httpd = HTTPServer(server_address, MyHandler)
print("Serving HTTP on port 8080...")
httpd.serve_forever()
