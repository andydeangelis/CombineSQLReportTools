function Get-ClusterResource
{
  param($cluster)
    gwmi -ComputerName $cluster -Authentication PacketPrivacy -Namespace "root\mscluster" -Class MSCluster_Resource | add-member -pass NoteProperty Cluster $cluster | 
    add-member -pass ScriptProperty Node `
    { gwmi -namespace "root\mscluster" -computerName $this.Cluster -Authentication PacketPrivacy -query "ASSOCIATORS OF {MSCluster_Resource.Name='$($this.Name)'} WHERE AssocClass = MSCluster_NodeToActiveResource" | Select -ExpandProperty Name } |
    add-member -pass ScriptProperty Group `
    { gwmi -ComputerName $this.Cluster -Authentication PacketPrivacy -Namespace "root\mscluster" -query "ASSOCIATORS OF {MSCluster_Resource.Name='$($this.Name)'} WHERE AssocClass = MSCluster_ResourceGroupToResource" | Select -ExpandProperty Name }
}