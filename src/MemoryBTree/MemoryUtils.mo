import Blobify "../Blobify";
import MemoryCmp "../MemoryCmp";

module {
    public let Nat = (Blobify.Nat, Blobify.Nat, MemoryCmp.Nat);

    public let Text = (Blobify.Text, Blobify.Text, MemoryCmp.Text);
}