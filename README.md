vSPD
====

vectorised Scheduling, Pricing and Dispatch - an audited, mathematical replica of SPD.

Input GDX files are available daily from ..\Datasets\Wholesale\Final_pricing\GDX\ at
ftp://ftp.emi.ea.govt.nz

The Electricity Authority wrote vSPD using the GAMS software in 2008. Dr Ramu Naidoo
was the original author and custodian of vSPD until Nov 2013. Dr Phil Bishop and Tuong
Nguyen now take care of vSPD. Others at the Electricity Authority also contribute.

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

Contact: emi@ea.govt.nz


TODO:
- Aliases yet to be considered
  i_bid(*)         as bid ???,
- The ability to add new set elements through the override facility has been implemented - with just offers for now. To reduce the code required, consider
  putting new offer, node, branch and constraint elements into the same symbol in the override GDX file.
