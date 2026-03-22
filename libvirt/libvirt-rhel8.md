# Libvirt VMs on AC922 (RHEL8 ppc64le)

To get Virtual Machines to start in libvirt on AC922 machines running RHEL8, you need to apply the following xml settings in the target domain:

1. Set `domain` tag to use qemu xml schema.

    ```xml
    <domain xmlns:qemu="http://libvirt.org/schemas/domain/qemu/1.0" type="kvm">
    ```

2. Machine Type has to be setup as `pseries-rhel7.6.0`.

    ```xml
    <os>
    <type arch="ppc64le" machine="pseries-rhel8.6.0">hvm</type>
    </os>
    ```

3. Setting `cap-ibs=fixed-ibs`

    Put it inside the `<domain>` block, you can add it just before the closing tag `</domain>`.
    It sets the Indirect Branch Serialisation (IBS) capability on IBM POWER architecture guests

    ```xml
    <qemu:commandline>
    <qemu:arg value="-machine"/>
    <qemu:arg value="cap-ibs=fixed-ibs"/>
    </qemu:commandline>
    ```