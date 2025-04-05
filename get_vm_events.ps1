$vm_list = (
    'VM_name_1',
    'VM_name_2'
)

foreach ($vm in $vm_list) {
    Get-VM -Name $vm | Get-VIEvent > ./$vm-full_detail.txt
    Get-VM -Name $vm | Get-VIEvent | Select-Object CreatedTime,FullFormattedMessage > ./$vm-short_detail.txt
}