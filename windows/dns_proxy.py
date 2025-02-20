import socket
import threading
import requests
from dnslib import DNSRecord

# Get the corporate DNS server from Windows
def get_windows_dns():
    try:
        response = requests.get("http://localhost:5050/dns")  # Change this if running another method
        return response.text.strip()
    except:
        return "8.8.8.8"  # Fallback to Google DNS if needed

DNS_SERVER = get_windows_dns()  # Use Windows' DNS server

def handle_request(data, addr, sock):
    try:
        # Parse the DNS request
        request = DNSRecord.parse(data)
        query_name = str(request.q.qname)

        # Forward request to the real DNS server
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as dns_sock:
            dns_sock.sendto(data, (DNS_SERVER, 53))
            response_data, _ = dns_sock.recvfrom(512)

        # Send response back to the requester (WSL)
        sock.sendto(response_data, addr)
        print(f"Resolved {query_name} via {DNS_SERVER}")

    except Exception as e:
        print(f"DNS Proxy Error: {e}")

def start_dns_proxy():
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind(("127.0.0.1", 5353))  # Listen on localhost:5353

    print(f"DNS Proxy started on 127.0.0.1:5353, forwarding to {DNS_SERVER}")

    while True:
        data, addr = sock.recvfrom(512)
        threading.Thread(target=handle_request, args=(data, addr, sock)).start()

if __name__ == "__main__":
    start_dns_proxy()
