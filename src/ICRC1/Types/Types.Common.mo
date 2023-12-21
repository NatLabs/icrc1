
module {

    ///This value-type is used for the token metadata
    public type Value = { #Nat : Nat; #Int : Int; #Blob : Blob; #Text : Text};
    
    ///Balance type, that is used by many modules
    public type Balance = Nat;
        
};
