vSPD (RTP4 development)
====

vectorised Scheduling, Pricing and Dispatch - an audited, mathematical replica of SPD, the
pricing and dispatch engine used in the New Zealand electricity market.

[Input GDX files are published daily on the Electricity Authority website](https://www.ea.govt.nz/data-and-insights/datasets/wholesale/dispatch-and-pricing/gdx/) or 
can be obtained directly from the underlying Azure storage account (see [instructions](https://www.emi.ea.govt.nz/Forum/thread/new-access-arrangements-to-emi-datasets-retirement-of-anonymous-ftp/) 
on the EMI forum).

The Electricity Authority created vSPD using the GAMS software in 2008. Dr Ramu Naidoo was
the original author and, until November 2013, the custodian of vSPD. Tuong Nguyen and Phil Bishop
from the Data and Information Management team maintained the vSPD model until December 2025.
Corey Kok from the Monitoring Projects team now maintains the vSPD model. 

Throughout 2022, vSPD was extensively modified to accomodate the 1 November 2022 go-live of real-time pricing. Backward 
compatability with GDX files was broken with this change.

Version 3.1.0, available on [Github,](https://github.com/ElectricityAuthority/vSPD/tree/v.3.1.0) is
the last version of vSPD to work with [GDX files](https://www.ea.govt.nz/data-and-insights/datasets/wholesale/dispatch-and-pricing/pre1november2022archive/gdx/) pertaining to all days up to and 
including 31 October 2022.

Version 4.0.0, also available on [Github,](https://github.com/ElectricityAuthority/vSPD/tree/v4.0.0) is
the first version of vSPD to work with [GDX files](https://www.ea.govt.nz/data-and-insights/datasets/wholesale/dispatch-and-pricing/gdx/) pertaining to all days since 
1 November 2022.

Version 5.0.0, available on [Github,](https://github.com/ElectricityAuthority/vSPD/tree/v.5.0.0) is
the new revamped vSPD to work with [daily pricing GDX files](https://www.ea.govt.nz/data-and-insights/datasets/wholesale/dispatch-and-pricing/gdx/) pertaining to all days since 1 November 2022. This vSPD version used the new GDX files that have new data structure. 

All versions, v3.1.0, v4.0.0 and v5.0.0, are also available from the [releases page](https://github.com/ElectricityAuthority/vSPD/releases) of this GitHub repository.

For more information, see the [APIs and tools](https://www.ea.govt.nz/data-and-insights/tools-and-apis/#vspd) page on the Electricity Authority website

Contact: emi@ea.govt.nz
