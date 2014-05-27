vSPD
====

vectorised Scheduling, Pricing and Dispatch - an audited, mathematical replica of SPD, the
pricing and dispatch engine used in the New Zealand electricity market.

Input GDX files are available daily from ..\Datasets\Wholesale\Final_pricing\GDX\ at
ftp://ftp.emi.ea.govt.nz.

The Electricity Authority created vSPD using the GAMS software in 2008. Dr Ramu Naidoo was
the original author and, until November 2013, the custodian of vSPD. Dr Phil Bishop and Tuong
Nguyen now take care of vSPD. Others at the Electricity Authority also contribute.

27 May 2014:
 - uploaded v1.4.1 - includes modifications to accomodate dispatchable demand
 - uploaded v1.4.2 - includes modifications to accomodate scarcity pricing and variable reserve
 - uploaded v1.4.3 - includes modifications to accomodate FTR rental calculation with five hubs


Several frequently-used basic sets are aliased as follows:
- i_island = ild, ild1
- i_dateTime = dt
- i_tradePeriod = tp
- i_node = n
- i_offer = o, o1
- i_trader = trdr
- i_tradeBlock = trdBlk
- i_bus = b, b1, frB, toB
- i_branch = br, br1
- i_lossSegment = los, los1
- i_branchConstraint = brCstr
- i_ACnodeConstraint = ACnodeCstr
- i_MnodeConstraint = MnodeCstr
- i_energyOfferComponent = NRGofrCmpnt
- i_PLSRofferComponent = PLSofrCmpnt
- i_TWDRofferComponent = TWDofrCmpnt
- i_ILRofferComponent = ILofrCmpnt
- i_energyBidComponent = NRGbidCmpnt
- i_ILRbidComponent = ILbidCmpnt
- i_type1MixedConstraint = t1MixCstr
- i_type2MixedConstraint = t2MixCstr
- i_type1MixedConstraintRHS = t1MixCstrRHS
- i_genericConstraint = gnrcCstr


Contact: emi@ea.govt.nz


TODO:
- Aliases yet to be considered
  i_bid(*)         as bid ???,
- The ability to add new set elements through the override facility has been implemented - with
  just offers for now. To reduce the code required, consider putting new offer, node, branch and
  constraint elements into the same symbol in the override GDX file.
