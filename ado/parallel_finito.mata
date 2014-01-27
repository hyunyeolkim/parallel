*! version 0.13.10.3  3oct2013
* Waits until every process finishes or stops the processes
mata:
real scalar parallel_finito(
	string scalar parallelid,
	| real scalar nclusters,
	real scalar timeout
	)
	{
	
	display(sprintf("{it:Waiting for the clusters to finish...}"))
	
	// Setting default parameters
	if (nclusters == J(1,1,.)) nclusters = strtoreal(st_global("PLL_CLUSTERS"))
	if (timeout == J(1,1,.)) timeout = 6000
	
	// Variable definitios
	real scalar in_fh, out_fh, time
	real scalar suberrors, i, errornum
	string scalar fname
	string scalar msg
	real scalar bk, pressed
	real rowvector pendingcl
	
	// Initial number of errors
	suberrors = 0
	
	/* Temporaly sets break key off */
	/* In windows (by now) parallel cannot use the breakkey */
	bk=querybreakintr();
	if (c("os")!="Windows") 
	{
		bk = setbreakintr(0)
		pressed=0
	}
	
	/* Checking conextion timeout */
	pendingcl = J(1,0,.)
	for(i=1;i<=nclusters;i++)
	{		
		/* Building filename */
		fname = sprintf("__pll%s_do%g.log", parallelid, i)
		time = 0
		while (!fileexists(fname) & ((++time)*100 < timeout) & !breakkey())
			stata("sleep 100")
			
		if (!fileexists(fname)) 
		{
			display(sprintf("{it:cluster %g} {error:has finished with a connection error -601- (timeout) ({stata search r(601):see more})...}", i))
			suberrors++
			continue
		}
		else pendingcl = pendingcl, i
			
		timeout = timeout - time*100
	}
	
	/* If there are as many errors as clusters, then exit */
	if (suberrors == nclusters) return(suberrors)
	
	while(length(pendingcl)>0)
	{
		
		// Building filename
		for (i=1;i<=nclusters;i++)
		{
			/* If this cluster is ready, then continue */
			if (!any(pendingcl :== i)) continue
			
			fname = sprintf("__pll%s_finito%g", parallelid, i)
			
			if (breakkey() & !pressed) 
			{ /* If the user pressed -break-, each instance will try to finish the work through parallel finito */
				/* Message */
				display(sprintf("{it:The user pressed -break-. Trying to stop the clusters...}"))
			
				/* Openning and checking for the new file */
				fname = sprintf("__pll%s_break", parallelid)
				if (fileexists(fname)) _unlink(fname)
				out_fh = fopen(fname, "w", 1)
				
				/* Writing and exit */
				fput(out_fh, "1")
				fclose(out_fh)
				
				pressed = 1
				fname = sprintf("__pll%s_finito%g", parallelid, i)
				
			}
		
			if (fileexists(fname)) // If the file exists
			{ 
				/* Opening the file and looking for somethign different of 0
				(which is clear) */
				in_fh = fopen(fname, "r", 1)
				if ((errornum=strtoreal(fget(in_fh))))
				{
					msg = fget(in_fh)
					if (msg == J(0,0,"")) display(sprintf("{it:cluster %g} {error:has finished with an error -%g- ({stata search r(%g):see more})...}", i, errornum, errornum))
					else display(sprintf("{it:cluster %g} {error:has finished with an error -%g- %s ({stata search r(%g):see more})...}", i, errornum, msg, errornum))
					suberrors++
				}
				else display(sprintf("{it:cluster %g} {text:has finished without any error...}", i))
				fclose(in_fh)
				
				/* Taking the finished cluster out of the list */
				pendingcl = select(pendingcl, pendingcl :!= i)
				
				continue
			} /* Else just wait for it 1/10 of a second! */
			else stata("sleep 100")
		}
	}
	
	/* Returing to old break value */
	if (querybreakintr()!=bk) 
	{
		breakkeyreset()
		(void) setbreakintr(bk)
	}
	
	return(suberrors)
	
}
end