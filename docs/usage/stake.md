# Staking

In Walrus, anyone can delegate stake to storage nodes and, by doing so, influence, which storage
nodes get selected for the committee in future epochs, and how many shards these nodes will hold.
Shards are assigned to storage nodes every epoch, roughly proportional to the amount of stake
that was delegated to them. By staking with a storage node, users also earn rewards, as they
will receive a share of the storage fees.

Since moving shards from one storage node to another requires transferring a lot of data and
storage nodes potentially need to expand their storage capacity, the selection of the committee
for the next epoch is done ahead of time, in the middle of the previous epoch. This provides
sufficient time to storage node operators to provision additional resources, if needed.

For stake to affect the shard distribution in epoch `e` and become "active", it must be staked
before the committee for this epoch has been selected, meaning that it has to be staked before
the midpoint of epoch `e - 1`. If it is staked after that point in time, it will only influence
the committee selection for epoch `e + 1` and thus only become active, and accrue rewards, in
that epoch.

Unstaking has a similar delay: because unstaking funds only has an effect on the committee in
the next committee selection, the stake will remain active until that committee takes over.
This means that, to unstake at the start of epoch `e`, the user needs to "request withdrawal"
before the midpoint of epoch `e - 1`. Otherwise, i.e., if the user unstakes after this point,
the stake will remain active, and continue to accrue rewards, throughout epoch `e`, and the
balance and rewards will be available to withdraw at the start of epoch `e + 1`.

## How to stake

### Walrus Staking dApp

The Walrus Staking dApp allows users to stake (or unstake) to any of the storage nodes of the system

### How to use the dApp

- Visit [https://stake.walrus.site](https://stake.walrus.site)
- Connect your wallet
  - Click the `Connect Wallet` button at the top right corner
  - Select the wallet (if the wallet was connected before this and the next step wont be required)
  - Approve the connection
  - (Make sure the selected wallet network is Testnet)

### Exchange Testnet SUI to WAL

To be able to stake you will need to have WAL in your wallet.
You can exchange your Testnet SUI to WAL using the dApp

- Click the `Get WAL` button
- Select the amount of SUI
- And click `Exchange`
- (Follow the instructions in your wallet to approve the transaction)

### Stake

- Find the Storage node that you want to stake to
  - Below the system stats there is the list of the `Current Committee` of storage nodes
  - You can select one of the nodes in that list
  - or if the storage node is not in the current committee
    - find all the Storage nodes at the bottom of the page
- Once you selected the Storage node click the stake button
- Select the amount of WAL
- Click Stake
- (Follow the instructions in your wallet to approve the transaction)

### Unstake

- Find the `Staked Wal` you want to unstake
  - Below the `Current Committee` list you will find all your `Staked Wal`
  - Also you can expand a Storage Node and find all your stakes with that node
- Depending on the state of the `Staked Wal` you will be able to Unstake or Withdraw your funds
- Click the `Unstake` or `Withdraw` button
- Click continue to confirm your action
- (Follow the instructions in your wallet to approve the transaction)

<!-- TODO -->

- How to monitor nodes for stake / apr etc
- Move contracts to stake / unstake
