# this script is used to bind pci device to the VFIO driver

BDF_REGEX="^[[:xdigit:]]{2}:[[:xdigit:]]{2}.[[:xdigit:]]$"
DBDF_REGEX="^[[:xdigit:]]{4}:[[:xdigit:]]{2}:[[:xdigit:]]{2}.[[:xdigit:]]$"

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi

if [[ $1 =~ $DBDF_REGEX ]]; then
    BDF=$1
elif [[ $1 =~ $BDF_REGEX ]]; then
    BDF="0000:$1"
    echo "Warning: You did not supply a PCI domain, assuming $BDF" 1>&2
else
    echo "Please supply Domain:Bus:Device.Function of PCI device in form: dddd:bb:dd.f" 1>&2
    exit 1
fi

TARGET_DEV_SYSFS_PATH="/sys/bus/pci/devices/$BDF"

if [[ ! -d $TARGET_DEV_SYSFS_PATH ]]; then
    echo "There is no such device"
    exit 1
fi

if [[ ! -d "$TARGET_DEV_SYSFS_PATH/iommu/" ]]; then
    echo "No signs of an IOMMU. Check your hardware and/or linux cmdline parameters." 1>&2
    echo "Use intel_iommu=on or iommu=pt iommu=1" 1>&2
    exit 1
fi

for dsp in $TARGET_DEV_SYSFS_PATH/iommu_group/devices/*
do
    dbdf=${dsp##*/}
    if [[ $(( 0x$(setpci -s $dbdf 0e.b) & 0x7f )) -eq 0 ]]; then
	dev_sysfs_paths+=( $dsp )
    fi
done

printf "\nIOMMU group members (sans bridges):\n"
for dsp in ${dev_sysfs_paths[@]}; do echo $dsp; done


printf "\nUnbinding...\n"
for dsp in ${dev_sysfs_paths[@]}
do
    dpath="$dsp/driver"
    dbdf=${dsp##*/}

	echo $dbdf > "$dpath/unbind"
	echo "Unbound $dbdf from $curr_driver"
	
	echo "rebind to original driver"
    echo $dbdf > /sys/bus/pci/drivers_probe
done

printf "\n"

# Adjust group ownership
echo 'Devices listed in /sys/bus/pci/drivers/vfio-pci:'
ls -l /sys/bus/pci/drivers/vfio-pci | egrep [[:xdigit:]]{4}:
printf "\nls -l /dev/vfio/\n"
ls -l /dev/vfio/
