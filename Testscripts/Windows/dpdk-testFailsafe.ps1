# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the Apache License.

function Configure-Test() {
	$nics = Get-NonManagementNics "forwarder"
	$nics[0].EnableIPForwarding = $true
	$nics[0] | Set-AzureRmNetworkInterface
}

function Alter-Runtime() {
	if ($currentPhase -eq "READY_FOR_REVOKE") {
		$nics = Get-NonManagementNics "forwarder"
		$nics[0].EnableAcceleratedNetworking = $false
		$nics[0] | Set-AzureRmNetworkInterface

		Change-Phase "REVOKE_DONE"
	} elseif ($currentPhase -eq "READY_FOR_VF") {
		$nics = Get-NonManagementNics "forwarder"
		$nics[0].EnableAcceleratedNetworking = $true
		$nics[0] | Set-AzureRmNetworkInterface

		Change-Phase "VF_RE_ENABLED"
	}
}

function Verify-WithinPercentage() {
	param (
		[double]$num0,
		[double]$num1,
		[double]$percent
	)

	$larger = $num0
	$smaller = $num1
	if ($smaller -gt $larger) {
		$larger = $num1
		$smaller = $num0
	}

	$difference = ($larger - $smaller) / $smaller * 100

	if ($difference -gt $percent) {
		return $false
	}

	return $true
}

function Verify-Performance() {
	# count is non header lines
	$isEmpty = ($testDataCsv.Count -eq 0)
	if ($isEmpty) {
		throw "No data downloaded from vm"
	}

	foreach($phaseData in $testDataCsv) {
		if ($phaseData.phase -eq "before") {
			$before_rx_pps = [int]$phaseData.fwdrx_pps_avg
			$before_tx_pps = [int]$phaseData.fwdtx_pps_avg
		} elseif ($phaseData.phase -eq "after") {
			$after_rx_pps = [int]$phaseData.fwdrx_pps_avg
			$after_tx_pps = [int]$phaseData.fwdtx_pps_avg
		}
	}

	return (Verify-WithinPercentage $before_rx_pps $after_rx_pps 10) -and
			(Verify-WithinPercentage $before_tx_pps $after_tx_pps 10)
}
