# install first http://support.microsoft.com/kb/2494036
Import-Module FailoverClusters

$node = "SQL3"
(Get-ClusterNode $node).NodeWeight = 0

$cluster = (Get-ClusterNode $node).Cluster
$nodes = Get-ClusterNode -Cluster $cluster

$nodes | Format-Table -property NodeName, State, NodeWeight
