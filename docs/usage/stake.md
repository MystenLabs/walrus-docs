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

<!-- TODO -->

- Stake / Unstake dApp link and docs
- How to monitor nodes for stake / apr etc
- Move contracts to stake / unstake
