import requests
import json
import time
from web3 import Web3
from datetime import datetime
import telebot

########################################### Scheduler to repeat the code every one minute ###########################################
########################################### Scheduler to repeat the code every one minute ###########################################

# Addresses
# Wemix 3.0 network

wemix_addresses = [
    "0x57192CCA8b8e4bEb77F3466C6D0550e64Cc53B0F",
    "0xEaB8e0E07e80c35Fef600C988EC0121b1317696b",
    "0x446cd4BB55dD7cddD97D7EB8dBEF193Af3687273",
    "0xC5FFDA0067c63bC94D6Fa1248C2fc32eB3858a76",
    #"0x914B35276CB43CF64168Dc7FaB4EfBc423618014"
]

wemix_contract_address = [
    "0xE3F5a90F9cb311505cd691a46596599aA1A0AD7D" # USDC on Wemix 3.0 network
]

"""
# Wemix test address
wemix_addresses = [
    "0x914B35276CB43CF64168Dc7FaB4EfBc423618014"
]
"""

# Ethereum network

eth_addresses = [
    "0x57192CCA8b8e4bEb77F3466C6D0550e64Cc53B0F",
    "0x62271357211D8A325165d61b60F0EdcACC05Bd3e",
    "0x6225C189f583fC2E17f5Be36A6A9db4d3978872D",
    #"0x914B35276CB43CF64168Dc7FaB4EfBc423618014"
]

eth_contract_addresses = [
    "0x2c69095d81305F1e3c6ed372336D407231624CEa",
    "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    #"0x07865c6E87B9F70255377e024ace6630C1Eaa37F" # Goerli USDC
]


"""
# For testing on goerli
eth_addresses = [
    "0x914B35276CB43CF64168Dc7FaB4EfBc423618014" # my eth address
]
eth_contract_addresses = [
    "0x07865c6E87B9F70255377e024ace6630C1Eaa37F" # USDC on goerli
]
"""

    
# Polygon network
polygon_addresses = [
    "0x57192CCA8b8e4bEb77F3466C6D0550e64Cc53B0F"
]

# 기존에 알고 있는 주소 목록
# 나중에 Txn이 발생하면 여기에 있는 주소들과 비교해서 있다면 주소 명칭으로 표시하기로 업데이트 예정. 
known_addresses_wemix = {
    "Multichain router contract": "0x818ec0a7fe18ff94269904fced6ae3dae6d6dc0b",
    "Weswap Contract" : "0x80a5A916FB355A8758f0a3e47891dc288DAC2665",
    "Play bridge" : "0x8443aE01eB9B0b5019F27b0B023fCCDAB72D96b7",
    "Bridge wallet" : "0xb572eb6a46C997a9BFB64C95589d573C8A51b5A9",
    "Bridge wallet 2" : "0x3D6A781D4D91d5A420411724b41B707AbE51A10d",
    "Ozys Miner" : "0x445f863df0090f423a6d7005581e30d5841e4d6d",
    "GDAC" : "0xc5bc3873d0fe77398a55f4ace6fa4bded772e228",
    "GDAC2" : "0xF14a18eBdD6755e2831049c54dEcc868d600bA86",
    "IndoDax" : "0x23f605B55C33f2396D6A939d4369CB354f10C1E5",
    "BitMart" : "0xb6dd6a186e1c3adbf1c4d3a21d7d2692658870f8",
    "BitMart2" : "0x5b389714C274C2C1fE0AAf9760F9415fEdc3Eb36",
    "CoinOne" : "0xD2Aa473e162fb6B4CecD84BebbAD8Eb0814da2d5",
    "Mercado" : "0x253462cca51d9599018b3e67922498c8be0d9e3d",
    "Mercado2" : "0xb8bA36E591FAceE901FfD3d5D82dF491551AD7eF",
    "MEXC" : "0x647a24B0281444b747Bb0d5372324ed0905be0E5",
    "Houbi" : "0x79354C3329c5ace803F0213E8bD6bE097fe87e2c"
}
known_addresses_eth = {

}

# URL for various networks
url_wemix = "https://api.wemix.com"
url_eth = "https://mainnet.infura.io/v3/0c926d471842463fb7b7196054fc5bde"
url_testnet_eth = "https://goerli.infura.io/v3/0c926d471842463fb7b7196054fc5bde"

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

# Main function to call on the token balances from WEMIX node. 
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
    
    # WEMIX token contract needed to interact with token balance
    if token_contract == "0x2c69095d81305F1e3c6ed372336D407231624CEa":
        result_2 = result_1/1e18
    
    # USDC token contract needed to interact with token balance
    if token_contract == "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48":
        result_2 = result_1/1e6
        
    return result_2

# Telegram bot send function
def send_telegram_message(bot_token, chat_id, message):
    url = f"https://api.telegram.org/bot{bot_token}/sendMessage"
    payload = {
        "chat_id": chat_id,
        "text": message,
        "parse_mode": "HTML",
        "disable_web_page_preview": True,
    }
    response = requests.post(url, json=payload)
    return response.json()

# Telegram bot send link function
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
def get_transactions_wemix(address, contract_addresses, url, block_number):
    print(f"blocknumber: {block_number}")
    print("inside get transaction wemix")
    transactions = []
    transaction_found = False
    transfer_method_signature = "0xa9059cbb"
    for block_index in range(block_number - 30, block_number + 1):
    #for block_index in range(block_number - 3, block_number + 3):
        print("inside block index for loop")
        print(f"blocknumber: {block_index}")
        payload = {
            "jsonrpc": "2.0",
            "method": "eth_getBlockByNumber",
            "params": [hex(block_index), True],
            "id": 1
        }
        response = requests.post(url, json=payload)
        block = response.json()['result']
        print("get block result")

        """
        for tx in block["transactions"]:
            if tx["from"].lower() == address.lower() or tx["to"].lower() == address.lower():
                transactions.append(tx)
        """

        for tx in block["transactions"]:
            print("now looking for transactions with address in that one block")
            # Check to see if there was a ERC-20 token transfer first
            for contract_address in contract_addresses:
                print("Inside erc-20 token transfer 'for' function")
                if tx["to"] == contract_address.lower() and tx["input"].startswith(transfer_method_signature):
                    #Extract the 'to' address from the input data
                    to_address = "0x" + tx["input"][34:74]
                    if tx["from"] == address.lower() or to_address == address.lower():
                        print("found one, erc-20 token transfer")
                        #transactions.append(tx)
                        transaction_data = {
                            'from': tx['from'],
                            'to': to_address,
                            'hash': tx['hash']
                        }
                        return transaction_data

            # If the above ERC-20 transfer didn't happen then it means there was a native token transfer
            if tx["from"] == address.lower() or tx["to"] == address.lower():

                print("found one, native token transfer")
                transaction_found = True
                transaction_data = {
                    'from': tx['from'],
                    'to': tx['to'],
                    'hash': tx['hash']
                }
                return transaction_data

    if transaction_found == False:
        print("Didn't find any transfers so return 'False'")
        return False


# Get transactions from Ethereum network
def get_transactions_eth(address, contract_addresses, url, block_number):
    print(f"blocknumber: {block_number}")
    print("inside get transaction eth")
    transactions = []
    transfer_method_signature = "0xa9059cbb"
    #for block_index in range(block_number - 5, block_number + 1):
    for block_index in range(block_number - 3, block_number + 3):
        print("inside block index for loop")
        print(f"blocknumber: {block_index}")
        payload = {
            "jsonrpc": "2.0",
            "method": "eth_getBlockByNumber",
            "params": [hex(block_index), True],
            "id": 1
        }
        response = requests.post(url, json=payload)
        block = response.json()['result']

        print("get block result")
        for tx in block["transactions"]:
            print("now looking for transactions with address in that one block")
            for contract_address in contract_addresses:
                if tx["to"] == contract_address.lower() and tx["input"].startswith(transfer_method_signature):
                    #Extract the 'to' address from the input data
                    to_address = "0x" + tx["input"][34:74]
                    if tx["from"] == address.lower() or to_address == address.lower():
                        print("found one, erc-20 token transfer")
                        #transactions.append(tx)
                        transaction_data = {
                            'from': tx['from'],
                            'to': to_address,
                            'hash': tx['hash']
                        }
                        return transaction_data

# Compare transaction address from known_address and return
def compare_address(address):
    for name, index in known_addresses_wemix.items():
        if address.lower() == index.lower():
            return name
        else:
            return address

count = 0
previous_balance_wemix = {}
previous_balance_eth = {}

#Initialize bot:
# Test bot
bot_token = "6220693290:AAHd2WGYNS5b9F9Cac_w7yWF4uVioETMv4I"
# Main bot
bot_token2 = "5961430353:AAENiehDUvjJ49K9Kw-fUAiGBhbV3jtPqrg"
        
#bot main group balance channel id: '-1001984709682'
#bot main group txn alert channel id: '-1001916320696'

#bot tester channel id_1 = '1628044387'
#bot tester channel id_2 = '-1001958836056'
#bot tester channel id_3 = '-1001828457128' -> last one I tested on. 
chat_id = '-1001984709682'
chat_id_alert = '-1001916320696'

while True:
    try:

        print(f'count: {count}')
        # For Wemix mainnet
        """
        # Get WEMIX balance and block number for wemix chain first
        wemix_balance = {}
        block_number_wemix = get_block_number(url_wemix)
        message_lines = [f"WEMIX Network"]
        message_lines.append(f"Block number [WEMIX] :: {block_number_wemix}")
        for address in wemix_addresses:
            balance = get_balance(address, url_wemix, block_number_wemix)
            wemix_balance[address] = balance
            message_lines.append(f"{address} :: {round(balance, 2)} WEMIX ")
        """
        message_lines = ""
        # Just for goerli testing
        wemix_balance = {}
        block_number_wemix = get_block_number(url_wemix)
        message_lines = [f"Wemix 3.0 Network"]
        message_lines.append(f"Block number [WEMIX] :: {block_number_wemix}")
        for address in wemix_addresses:
            print("Inside native token")
            balance = get_balance(address, url_wemix, block_number_wemix)
            wemix_balance[address] = balance
            message_lines.append(f"{address} :: {round(balance, 2)} WEMIX ")

        
        # Get balance on ETH wallet address and block number for ETH chain second
        block_number_eth = get_block_number(url_eth)
        message_lines.append(f"Ethereum Network")
        message_lines.append(f"Block number [Ethereum] :: {block_number_eth}")
        block_timestamp = get_block_timestamp(block_number_eth, url_eth)
        block_datetime = datetime.fromtimestamp(block_timestamp)
        result_eth = {}
        for address in eth_addresses:
            print("Inside eth erc-20 addresses")
            for token_contract in eth_contract_addresses:
                print("Inside eth erc-20 contract address")
                token_balance = get_token_balance(address, token_contract, url_eth, block_number_eth)
                result_eth[address] = token_balance

                # ETH WEMIX token
                if token_contract == '0x2c69095d81305F1e3c6ed372336D407231624CEa' :
                    message_lines.append(f"{address} :: {round(token_balance,2 )} WEMIX")
                
                # Goerli USDC
                if token_contract == '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48' and token_balance != 0:
                    message_lines.append(f"{address} :: {round(token_balance, 2)} USDC")
        
        

        # Add the balance into previous_balance to start comparing the next count
        if count == 0:
            print("setting previous balance")
            previous_balance_wemix = wemix_balance
            previous_balance_eth = result_eth
            print("successfully set previous balance")

        # Flags for sending message on telegram
        native = False
        erc20 = False

        # Checks to see if balance has changed
        if count >= 1:
            print("now count is more or equal to one")
            message_text1 = ""
            message_text2 = ""
            
            # Mainnet wemix code
            for address in wemix_addresses:
                if wemix_balance[address] != previous_balance_wemix[address]:
                    native = True
                    print("Inside previous native token - current comparison function")
                    # Get the transaction details 
                    transactions = get_transactions_wemix(address, eth_contract_addresses, url_wemix, block_number_wemix)
                    print("called the native token get transaction function")
                    if transactions:
                        tx_from = transactions['from']
                        tx_to = transactions['to']
                        tx_hash = transactions['hash']
                        temp = abs(wemix_balance[address] - previous_balance_wemix[address])
                        print("just printing out the messages")
                        # Print messages
                        print(f'🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨 Change in balance :: {temp}! in {address}')
                        message_lines.append(f"🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨\nChange in balance: {round(temp, 2)}! in {address}")
                        message_text1 = f"🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨\nFrom {tx_from} \nTo {tx_to}"
                        message_text1 += f"\n[Click here for Transactions](https://explorer.wemix.com/tx/{tx_hash})"
                    else:
                        temp = abs(wemix_balance[address] - previous_balance_wemix[address])
                        print(f'🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨 Change in balance :: {temp}! in {address}')
                        message_lines.append(f"🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨\nChange in balance: {round(temp, 2)}! in {address}")
                        # Update previous_balance to new balance
                        
                    previous_balance_wemix[address] = wemix_balance[address]

            
            # Checks to see if balance of Ethereum assets has changed
            for address in eth_addresses:
                if result_eth[address] != previous_balance_eth[address]:
                    erc20 = True
                    print("Inside previous other tokens - current comparison function")
                    # Get the transaction details 
                    transactions = get_transactions_eth(address, eth_contract_addresses, url_testnet_eth, block_number_eth)
                    print("called the erc-20 token get transaction function")
                    tx_from = transactions['from']
                    tx_to = transactions['to']
                    tx_hash = transactions['hash']
                    temp = abs(result_eth[address] - previous_balance_eth[address])
                    print("just printing out the messages")

                    # Print messages
                    print(f'🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨 Change in balance :: {temp}! in {address}')
                    message_lines.append(f"🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨\nChange in balance: {round(temp, 2)}! in {address}")
                    message_text2 = f"🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨\nFrom {tx_from} \nTo {tx_to}"
                    message_text2 += f"\n[Click here for Transactions](https://etherscan.io/tx/{tx_hash})"
                
                # Update previous_balance to new balance
                previous_balance_eth[address] = result_eth[address]
            
            
        print(f"Block number (WEMIX): {block_number_wemix}")
        #print(f"Block number (ETH): {block_number_eth}")
        print(wemix_balance)
        print(f"Block number (ETH): {block_number_eth}")
        print(result_eth)
        #print(f"Block timestamp: {block_timestamp} ({block_datetime})")
 
        count += 1
       
        # Main message to send for change in balance. 
        message = "\n".join(message_lines)
        send_telegram_message(bot_token2, chat_id_alert, message)

        # Secondary message to send for txn link alert
        if native == True and erc20 == True:
            send_telegram_link(chat_id_alert, message_text2, bot_token2)
        if native == True and erc20 == False:
            send_telegram_link(chat_id_alert, message_text1, bot_token2)
        if native == False and erc20 == True:
            send_telegram_link(chat_id_alert, message_text2, bot_token2)

    except Exception as e:
        print(f"Error: {e}")
    time.sleep(10)

