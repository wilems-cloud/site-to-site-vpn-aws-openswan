# site-to-site-vpn-aws-openswan
Capstone project demonstrating a secure Site-to-Site VPN connection between an on-premises network and AWS using OpenSwan (IPsec).

# Site-to-Site VPN Connection Using OpenSwan on AWS

This project demonstrates how to securely connect an on-premises environment to AWS using a Site-to-Site VPN with OpenSwan, an open-source IPsec-based VPN solution.

## 🧩 Problem Statement

Companies often need secure communication between their on-premises data centers and cloud environments. This project simulates a real-world scenario of building a site-to-site VPN to bridge those environments securely, enabling private data flow across hybrid infrastructure.

## 💡 Solution Overview

This project sets up:
- Two VPCs (representing on-premises and cloud)
- A VPN connection between them using OpenSwan and AWS Site-to-Site VPN
- EC2 instances in each VPC to test end-to-end encrypted communication

## ⚙️ Key Technologies

- AWS VPC, VPN Gateway, Customer Gateway
- EC2 Instances (Amazon Linux 2)
- OpenSwan (IPsec VPN)
- Static routing


## 📁 Project Structure


