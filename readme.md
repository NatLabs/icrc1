# Build-status

![example branch parameter](https://github.com/github/docs/actions/workflows/main.yml/badge.svg?branch=main&kill_cache=1&event=push)

# ICRC-1 Implementation details 
- This repo contains the implementation of the [ICRC-1](https://github.com/dfinity/ICRC-1) token standard. 
- Code of the [SNEED ICRC token](https://github.com/icsneed/sneed) was merged into this repository.  
- Two executable test packages are included. Internal tests and a copy of [Dfinity reference tests](https://github.com/dfinity/ICRC-1/tree/main/test).
- Not only the ICRC1 specification is implemented, but also some additional features are included into this token.


## Additional features

- <b>Minting_allowed</b></br>
  The init-argument has additional field 'minting_allowed'. If this is set to false then minting feature is disabled.

- <b>Auto fill up archive canisters with cycles</b> <br/>
  The transaction history is kept inside dynamically created archive canisters. So after every 2000 transactions, the
  transactions are moved from the cache into the archive canister(s). And therefore it is important that the archive canisters are holding
  enough cycles for these operations. Therefore the feature to auto-fill-up the archive canisters was added.
  To enable this feature, please call this canister function:</br>
  ```dfx canister call icrc1 auto_topup_cycles_enable```</br>
  Then the feature is enabled with the default timer interval of 12 hours. (So every 12 hours the cycles of the archive canisters will be checked, and if they hold less than the specified threshold then the cycles are filled up from the main token canister.
  The threshold value is defined in file 'Types\Types.Constants.mo' :</br>
  ```public let ARCHIVE_CYCLES_REQUIRED = 100_000_000_000```


  You can also specifiy the used timer interval, in which the archive canisters should be checked. In this example every 25 minutes:</br>
  ```dfx canister call icrc1 auto_topup_cycles_enable 'opt(25)'```
  </br></br>
  To disable this feature:</br>
  ```dfx canister call icrc1 auto_topup_cycles_disable```
  </br></br>
  To see the status for this feature:</br>
  ```dfx canister call icrc1 auto_topup_cycles_status```
- <b>Get transactions history</b> </br>
   Get the total number of transactions:</br>

   ```dfx canister call icrc1 get_total_tx```</br>

   Get the first two transactions:</br>

   ```dfx canister call icrc1 get_transactions 'record {start=0; length=2}'``` 

- <b>Show available cycles for all canister's</b></br> 
   ```dfx canister call icrc1 all_canister_stats```

- <b>Get total number of token holders</b></br>
```dfx canister call icrc1 get_holders_count```

- <b>Get list of holders with their token balances</b></br>
  Maximum 5000 entries are returned. Therefore you can specify the 'index' and 'count' in the argument.</br></br>
  Get list of the first 5000 holders:</br>
  ```dfx canister call icrc1 get_holders```</br></br>
  Get specified holders-list. (argument is (index:?Nat, count:?Nat)) :</br>
  ```dfx canister call icrc1 get_holders '(2,3)'```</br>


## Getting Started 


- <b>(1) Clone this repo</b></br>
  ```git clone https://github.com/fGhost713/ICRC1-Implementation-with-tests.git```
  </br></br>
- <b>(2) Navigate into the repository-folder</b></br>
   ```cd ICRC1-Implementation-with-tests```
   </br></br>
- <b>(3) Install all the prerequisities</b></br>
```make install-check```</br></br>
- <b>(4) Reboot your computer now</b></br></br>
- <b>(5) Stop dfx service (in case it is running)</b></br>
```dfx stop```</br></br>
- <b>(6) Start dfx service</b></br>
```dfx start --background --clean```
    </br></br>
- <b>(7) Deploy your initial token on your local computer</b></br>
   Example:</br>

```
   dfx deploy icrc1 --with-cycles 3000000000000 -m reinstall --argument '( opt record {

      name = "MyCoolToken";
      symbol = "SYMB";
      decimals = 6;
      fee = 1_000_000;
      max_supply = 1_000_000_000_000;
      logo = "";
      initial_balances = vec {
          record {
              record {
                  owner = principal "fel5r-65awt-mqpqr-mjxze-nqg72-x5q3v-tjrny-ykm5e-xmk6l-3f5ny-lae";
                  subaccount = null;
              };
              300_000_000_000
          }
      };
      min_burn_amount = 10_000;
      minting_account = null;
      advanced_settings = null;
      minting_allowed = false;
  })'
  ```

- <b>(8) Update code changes</b></br>
  If you made some code changes and you want to upgrade the token with your changes:</br>
  ```dfx deploy icrc1```
  

## Tests

#### Internal Tests
- <b>Run the internal tests:</b></br>
```make internal-tests```</br>

#### Dfinity's ICRC-1 Reference Tests
- <b>Run the icrc1-reference tests:</b></br>
```make ref-test```</br></br>
</br>
## Funding

This original library was initially incentivized by [ICDevs](https://icdevs.org/). You can view more about the bounty on the [forum](https://forum.dfinity.org/t/completed-icdevs-org-bounty-26-icrc-1-motoko-up-to-10k/14868/54) or [website](https://icdevs.org/bounties/2022/08/14/ICRC-1-Motoko.html). The bounty was funded by The ICDevs.org community and the DFINITY Foundation and the award was paid to [@NatLabs](https://github.com/NatLabs). If you use this library and gain value from it, please consider a [donation](https://icdevs.org/donations.html) to ICDevs.