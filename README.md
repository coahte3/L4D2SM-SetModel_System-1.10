L4D2 SourceMod. -Set Models, -Set Startup Models, !ChatCommand<br> 
DL: <a href="https://github.com/coahte3/L4D2SM-SetModel_System-1.10/releases/download/1.10/L4D2.SetModel.System1.10.smx">L4D2SM-SetModel_System-1.10</a><br>
<br>
<b>ChatCommand:</b><br>
!model    // Menu<br>
!SetModel &lt;SurvivorName&gt;<br>
!SetModelJoin // Model currently set<br>
!SetModelJoin &lt;SurvivorName&gt; // Model changes during join (or "random")<br>
!SetModelJoinOn // Current Enable status<br>
!SetModelJoinOn &lt;1/0/Enable/Disable&gt;<br>
!SetModelAdmin &lt;Target&gt; &lt;SurvivorName&gt; // AdminOnly<br>
<br>
<b>&lt;Target&gt;</b><br>
all, @all, survivor, @survivors/ bot, bots, @bots/ me, @me/ 1~ (Client Number)/ PlayerName/ @aim<br>
<br>
<b>&lt;SurvivorName&gt;</b><br>
nick, ellis, coach, rochelle, bill, francis, louis, zoey<br>
<br>
<b>Example:</b><br>
!SetModel louis<br>
!SetModelJoin louis<br>
!SetModelAdmin all louis<br>
