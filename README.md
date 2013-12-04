vSPD
====

vectorised Scheduling, Pricing and Dispatch - an audited, mathematical replica of SPD, the
pricing and dispatch engine used in the New Zealand electricity market.

Input GDX files are available daily from ..\Datasets\Wholesale\Final_pricing\GDX\ at
ftp://ftp.emi.ea.govt.nz.

The Electricity Authority created vSPD using the GAMS software in 2008. Dr Ramu Naidoo was
the original author and, until November 2013, the custodian of vSPD. Dr Phil Bishop and Tuong
Nguyen now take care of vSPD. Others at the Electricity Authority also contribute.

Several frequently-used basic sets are aliased as follows:
Aliases to be aware of:
- i_island = ild, ild1                         i_dateTime = dt
- i_tradePeriod = tp                           i_node = n
- i_offer = o, o1                              i_trader = trdr
- i_tradeBlock = trdBlk                        i_bus = b, b1, frB, toB
- i_branch = br, br1                           i_lossSegment = los, los1
- i_branchConstraint = brCnstrnt               i_ACnodeConstraint = ACnodeCnstrnt
- i_MnodeConstraint = MnodeCnstrnt             i_energyOfferComponent = NRGofrCmpnt
- i_PLSRofferComponent = PLSofrCmpnt           i_TWDRofferComponent = TWDofrCmpnt
- i_ILRofferComponent = ILofrCmpnt             i_energyBidComponent = NRGbidCmpnt
- i_ILRbidComponent = ILbidCmpnt               i_type1MixedConstraint = t1MixCnstrnt
- i_type2MixedConstraint = t2MixCnstrnt        i_type1MixedConstraintRHS = t1MixCnstrntRHS
- i_genericConstraint = gnrcCnstrnt


Contact: emi@ea.govt.nz


TODO:
- Aliases yet to be considered
  i_bid(*)         as bid ???,
- The ability to add new set elements through the override facility has been implemented - with
  just offers for now. To reduce the code required, consider putting new offer, node, branch and
  constraint elements into the same symbol in the override GDX file.
