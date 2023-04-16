import requests
import json
import asyncio
import time
from aiohttp import ClientSession
from web3 import Web3
from datetime import datetime
from apscheduler.schedulers.blocking import BlockingScheduler
import telebot


########################################### Scheduler to repeat the code every one minute ###########################################
########################################### Scheduler to repeat the code every one minute ###########################################

# Addresses
# Wemix 3.0 network
"""
wemix_addresses = [
    "0x914B35276CB43CF64168Dc7FaB4EfBc423618014"
]
"""
wemix_addresses = [
    "0x57192CCA8b8e4bEb77F3466C6D0550e64Cc53B0F",
    "0xEaB8e0E07e80c35Fef600C988EC0121b1317696b",
    "0x446cd4BB55dD7cddD97D7EB8dBEF193Af3687273",
    "0xC5FFDA0067c63bC94D6Fa1248C2fc32eB3858a76"
]


# Ethereum network
eth_addresses = [
    "0x57192CCA8b8e4bEb77F3466C6D0550e64Cc53B0F",
    "0x62271357211D8A325165d61b60F0EdcACC05Bd3e",
    "0x6225C189f583fC2E17f5Be36A6A9db4d3978872D"
]

eth_contract_addresses = [
    "0x2c69095d81305F1e3c6ed372336D407231624CEa",
    "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
]
    
# Polygon network
polygon_addresses = [
    "0x57192CCA8b8e4bEb77F3466C6D0550e64Cc53B0F"
]

# URL for various networks
url_wemix = "https://api.wemix.com"
url_eth = "https://mainnet.infura.io/v3/0c926d471842463fb7b7196054fc5bde"

# Get block number
def get_block_number(url):
    payload = {
        "jsonrpc" : "2.0",
        "id" : 1,
        "method" : "eth_blockNumber",
        "params" : []
    }
    headers = {"Content-Type": "application/json"}
    response = requests.post(url, json=payload, headers=headers)
    result = json.loads(response.text)["result"]
    return int(result, 16)

# Get block number timestamp
def get_block_timestamp(block_number, url):
    payload = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "eth_getBlockByNumber",
        "params": [hex(block_number), False]
    }
    headers = {"Content-Type": "application/json"}
    response = requests.post(url, json=payload, headers=headers)
    result = json.loads(response.text)["result"]
    return int(result["timestamp"], 16)

# Main function to call on the token balances from main rpcs. 
def get_balance(address, url, block_number=None):
    
    block_param = "latest" if block_number is None else hex(block_number)
    
    payload = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "eth_getBalance",
        "params": [address, block_param]
    }
    headers = {"Content-Type": "application/json"}
    
    response = requests.post(url, json=payload, headers=headers)
    result = json.loads(response.text)['result']

    result_1 = int(result, 16)
    results_2 = result_1/1e18
    
    return results_2

# Ethereum rpc node call for specific token balance
def get_token_balance(wallet, token_contract, url, block_number=None):
    function_signature = "0x70a08231"
    padded_wallet = "0" * (64 - len(wallet[2:])) + wallet[2:]
    data = function_signature + padded_wallet
    
    block_param = "latest" if block_number is None else hex(block_number)
    
    payload = {
        "jsonrpc" : "2.0",
        "id" : 1,
        "method": "eth_call",
        "params": [
                {
                "to" : token_contract,
                "data": data
            },
            block_param
        ]
    }
    
    headers = {"Content-Type": "application/json"}
    response = requests.post(url, json=payload, headers=headers)
    result = json.loads(response.text)['result']
    result_1 = int(result, 16)
    if token_contract == "0x2c69095d81305F1e3c6ed372336D407231624CEa":
        result_2 = result_1/1e18
    if token_contract == "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48":
        result_2 = result_1/1e6
        
    return result_2

# Telegram bot send function
def send_telegram_message(bot_token, chat_id, message):
    url = f"https://api.telegram.org/bot{bot_token}/sendMessage"
    payload = {
        "chat_id": chat_id,
        "text": message
    }
    response = requests.post(url, json=payload)
    return response.json()

def send_telegram_link(chat_id, text, bot_token):
    url = f"https://api.telegram.org/bot{bot_token}/sendMessage"
    payload = {
        "chat_id": chat_id, 
        "text": text, 
        "parse_mode": "MarkdownV2"
    }

    response = requests.post(url, json=payload)
    return response.json()

# Get transaction on WEMIX network
def get_transactions_wemix(address, url, block_number):
    transactions = []
    for block_index in range(block_number - 25, block_number + 1):
        
        payload = {
            "jsonrpc": "2.0",
            "method": "eth_getBlockByNumber",
            "params": [hex(block_index), True],
            "id": 1
        }
        response = requests.post(url, json=payload)
        block = response.json()['result']

        for tx in block["transactions"]:
            if tx["from"].lower() == address.lower() or tx["to"].lower() == address.lower():
                transactions.append(tx)
    
    return transactions

# Get transactions from Ethereum network
def get_transactions_eth(address, url, block_number):
    transactions = []
    for block_index in range(block_number - 5, block_number + 1):
        
        payload = {
            "jsonrpc": "2.0",
            "method": "eth_getBlockByNumber",
            "params": [hex(block_index), True],
            "id": 1
        }
        response = requests.post(url, json=payload)
        block = response.json()['result']

        for tx in block["transactions"]:
            if tx["from"] == address or tx["to"] == address:
                transactions.append(tx)
    
    return transactions


count = 0
previous_balance_wemix = {}
previous_balance_eth = {}

#Initialize bot:
bot_token = "Insert Bot-Token here"
bot_token2 = "Insert Bot-Token here"
        

chat_id = 'Insert Chat Id here'
chat_id_alert = 'Insert Chat Id here'

while True:
    try:

        print(f'count: {count}')
        # Get WEMIX balance and block number for wemix chain first
        wemix_balance = {}
        block_number_wemix = get_block_number(url_wemix)
        message_lines = [f"WEMIX Network"]
        message_lines.append(f"Block number [WEMIX] :: {block_number_wemix}")
        for address in wemix_addresses:
            balance = get_balance(address, url_wemix, block_number_wemix)
            wemix_balance[address] = balance
            message_lines.append(f"{address} :: {round(balance, 2)} WEMIX ")
            


        # Get balance on ETH wallet address
        block_number_eth = get_block_number(url_eth)
        message_lines.append(f"Ethereum Network")
        message_lines.append(f"Block number [Ethereum] :: {block_number_eth}")
        block_timestamp = get_block_timestamp(block_number_eth, url_eth)
        block_datetime = datetime.fromtimestamp(block_timestamp)
        result_eth = {}
        for address in eth_addresses:
            for token_contract in eth_contract_addresses:
                token_balance = get_token_balance(address, token_contract, url_eth, block_number_eth)
                result_eth[address] = token_balance
                if token_contract == '0x2c69095d81305F1e3c6ed372336D407231624CEa' :
                    message_lines.append(f"{address} :: {round(token_balance,2 )} WEMIX")
                if token_contract == '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48' and token_balance != 0:
                    message_lines.append(f"{address} :: {round(token_balance, 2)} USDC")

        

        # Add the balance into previous_balance to start comparing the next count
        if count == 0:
            previous_balance_wemix = wemix_balance
            previous_balance_eth = result_eth

        # Compare previous balance 
        if count >= 1:
            for address in wemix_addresses:
                # Wemix chain balance checks
                if wemix_balance[address] != previous_balance_wemix[address]:
                    transactions = get_transactions_wemix(address, url_wemix, block_number_wemix)
                    tx_from = transactions[0]['from']
                    tx_to = transactions[0]['to']
                    tx_block_number = int(transactions[0]['blockNumber'], 16)
                    tx_hash = transactions[0]['hash']
                    temp = abs(wemix_balance[address] - previous_balance_wemix[address])
                    print(f'🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨 Change in balance :: {temp}! Block number: {tx_block_number } in {address}')
                    message_lines.append(f"🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨\nChange in balance: {round(temp, 2)}! in {address}")
                    message_tx_wemix = f"🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨\nChange in balance: {round(temp, 2)}! in {address}\nBlock number: {tx_block_number}!\nFrom {tx_from} to {tx_to}"
                    message_text_wemix = f"\n[Click here for Transactions](https://explorer.wemix.com/tx/{tx_hash})"
                    previous_balance_wemix[address] = wemix_balance[address]
                    
                    #send_telegram_message(bot_token, chat_id, message_tx_wemix)
                    send_telegram_message(bot_token2, chat_id_alert, message_tx_wemix)
                    send_telegram_link(chat_id_alert, message_text_wemix, bot_token2)

            # Ethereum chain balance checks
            for address in eth_addresses:
                if result_eth[address] != previous_balance_eth[address]:
                    transactions = get_transactions_eth(address, url_eth, block_number_eth)
                    tx_from = transactions[0]['from']
                    tx_to = transactions[0]['to']
                    tx_block_number = int(transactions[0]['blockNumber'], 16)
                    tx_hash = transactions[0]['hash']
                    temp = abs(result_eth[address] - previous_balance_eth[address])
                    print(f'🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨 Change in balance :: {temp}! Block number: {tx_block_number } in {address}')
                    message_lines.append(f"🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨\nChange in balance: {round(temp, 2)}! in {address}")
                    message_tx_eth = f"🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨\nChange in balance: {round(temp, 2)}! in {address}\nBlock number: {tx_block_number}!\nFrom {tx_from} to {tx_to}"
                    
                    message_text_eth = f"\n[Click here for Transactions](https://etherscan.io/tx/{tx_hash})"
                    previous_balance_eth[address] = result_eth[address]
                    
                    #send_telegram_message(bot_token, chat_id, message_tx_eth)
                    send_telegram_message(bot_token2, chat_id_alert, message_tx_eth)
                    send_telegram_link(chat_id_alert, message_text_eth, bot_token2)

        print(f"Block number (WEMIX): {block_number_wemix}")
        print(wemix_balance)
        print(f"Block number (ETH): {block_number_eth}")
        print(result_eth)
        print(f"Block timestamp: {block_timestamp} ({block_datetime})")
 
        count += 1
       
        message = "\n".join(message_lines)
        send_telegram_message(bot_token2, chat_id, message)

    except Exception as e:
        print(f"Error: {e}")
    time.sleep(10)


"""
# Initialize schedular
scheduler = BlockingScheduler()

# For 30 second interval
scheduler.add_job(start_code(), 'interval', seconds=10)
# For 1 minute interval
#scheduler.add_job(start_code, 'interval', minutes=1)
# For 2 minute interval
#scheduler.add_job(send_price_difference, 'interval', minutes=2)
scheduler.start()
"""

