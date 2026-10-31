import com.qnx.install.License;
import com.qnx.install.LicenseInfo;

// Adds a QNX SDP 6.5.0 licence key using QNX's own licence library
// (the same License.addLicense() call the installer's key panel makes).
// usage: AddKey <qnxlm_linux.so> <config dir> <key>
public class AddKey {
    public static void main(String[] a) throws Exception {
        System.load(a[0]);
        License.setLibraryLoaded();
        License.setLicenseDir(a[1]);
        String key = a[2];
        License.addLicense(License.ADD_ANY, key);
        LicenseInfo i = License.getInfoSerial(License.getSerial(key));
        System.out.println("added: product=" + i.productType + " serial=" + i.serial
            + " flags=0x" + Integer.toHexString(i.flags)
            + ((i.flags & LicenseInfo.EXPIRY) != 0 ? " expires-in=" + i.expireDays + "d" : " no-expiry")
            + ((i.flags & LicenseInfo.ACTIVATE) != 0 ? " needs-activation (" + i.activateDays + "d grace)" : " no-activation"));
    }
}
