#/bin/sh

FROM=$1
if [ -z $FROM ]
then
    FROM=1
fi

TO=$2
if [ -z $TO ]
then
    TO=2
fi

IP="$(dig +short myip.opendns.com @resolver1.opendns.com)"
echo "Public IP address: ${IP}"
PORT=16657

if [ -z $IP ]
then
    IP=127.0.0.1
    PORT=16657
fi

balace_query() {
balance=$("${DAEMON}" q bank balances $1 --node $RPC --output json)
balanceres=$(echo "${balance}" | jq -r '.balances')
return "$balanceres"
}

RPC="http://${IP}:${PORT}"
num_txs=35
num_msgs=30
acc1=$($DAEMON keys show account$FROM -a --home $DAEMON_HOME-1 --keyring-backend test)
acc2=$($DAEMON keys show account$TO -a --home $DAEMON_HOME-1 --keyring-backend test)
echo "** Balance of Account 1 before send_load :: **"
balace_query "$acc1"
echo "** Balance of Account 2 before send_load :: **"
balace_query "$acc2"
cd ~/
for (( a=0; a<$num_txs; a++ ))
do
		unsignedTx=$("${DAEMON}" tx bank send "${acc1}" "${acc2}" 1000000"${DENOM}" --chain-id "${CHAINID}" --output json --generate-only --gas 500000 > unsigned.json)
		unsignedTxres=$(echo "${unsignedTx}")
		for (( b=0; b<$num_msgs; b++))
		do
    		cat unsigned.json | jq '.body.messages |= . + [.[-1]]' > unsigned.json.bk
            mv unsigned.json.bk unsigned.json 
		done
		seq1=$("${DAEMON}" q account "${acc1}" --node $RPC --output json)
		seq1no=$(echo "${seq1}" | jq -r '.sequence')
		signTx=$("${DAEMON}" tx sign unsigned.json --from "${acc1}" --chain-id "${CHAINID}" --keyring-backend test --home $DAEMON_HOME-1 --node $RPC --signature-only=false --sequence $seq1no --gas 500000 > signed.json)
		signTxres=$(echo "${signTx}")
		broadcast=$("${DAEMON}" tx broadcast signed.json --output json --chain-id "${CHAINID}" --gas 500000 --node $RPC --broadcast-mode async)
		broadcastRes=$(echo "${broadcast}" | jq .txhash)
		echo $broadcastRes
done

for (( a=0; a<$num_txs; a++ ))
do
		unsignedTx=$("${DAEMON}" tx bank send "${acc2}" "${acc1}" 1000000"${DENOM}" --chain-id "${CHAINID}" --output json --generate-only --gas 500000 > unsigned.json)
		unsignedTxres=$(echo "${unsignedTx}")
		for (( b=0; b<$num_msgs; b++))
		do
    		cat unsigned.json | jq '.body.messages |= . + [.[-1]]' > unsigned.json.bk && mv unsigned.json.bk unsigned.json 
		done
		seq2=$("${DAEMON}" q account "${acc2}" --node $RPC --output json)
		seq2no=$(echo "${seq2}" | jq -r '.sequence')
		signTx=$("${DAEMON}" tx sign unsigned.json --from "${acc2}" --chain-id "${CHAINID}" --keyring-backend test --home $DAEMON_HOME-1 --node $RPC --signature-only=false --sequence $seq1no --gas 500000 > signed.json)
		signTxres=$(echo "${signTx}")
		broadcast=$("${DAEMON}" tx broadcast signed.json --output json --chain-id "${CHAINID}" --gas 500000 --node $RPC --broadcast-mode async)
		broadcastRes=$(echo "${broadcast}" | jq .txhash)
		echo $broadcastRes
done

sleep 7s
echo "** Balance of Account 1 after send_load :: **"
balace_query $acc1
echo "** Balance of Account 2 after send_load ::  **"
balace_query $acc2