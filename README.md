# Satsuma 🍊
A simple onchain wallet.

🛠 Satsuma is an early stage, "work in progress", although fully functional wallet. 

Satsuma is a native iOS wallet which focuses on security, simplicity and ease of use.

Testnet functionality is available, mainnet is default.

Satsuma utilizes the Esplora API to search for utxo's via the `https://mempool.space/api/address/<address>/utxo` endpoint.

All other wallet functionality is powered by [Libwally-Swift](https://github.com/Sjors/libwally-swift). 

The only network commands the wallet makes are for fetching utxo's via address, to mempool.space for fetching the "recommended fee" and broadcasting transactions.

Users may utilize their own Esplora instance via the "custom server" setting. It works with mempool.space, blockstream.info or any Esplora powered API.

Onion endpoints will work if the user toggles on Tor, onion endpoints are automatically utilized if Tor is on for public servers.

For a list of todo items see the issues.

Help testing and feedback would be much appreciated.



