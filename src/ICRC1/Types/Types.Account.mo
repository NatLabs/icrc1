import STMap "mo:StableTrieMap";
import CommonTypes "Types.Common"

module{
    
    public type EncodedAccount = Blob;
    public type Subaccount = Blob;
    public type AccountBalances = STMap.StableTrieMap<EncodedAccount, CommonTypes.Balance>;

    public type ParseError = {
        #malformed : Text;
        #not_canonical;
        #bad_checksum;
    };

    public type Account = {
        owner : Principal;
        subaccount : ?Subaccount;
    };
};
