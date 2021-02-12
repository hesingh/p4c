#include <core.p4>
#include <ebpf_model.p4>

typedef bit<48> EthernetAddress;
header Ethernet_h {
    EthernetAddress dstAddr;
    EthernetAddress srcAddr;
    bit<16>         etherType;
}

header IPv6_h {
    bit<32>  ip_version_traffic_class_and_flow_label;
    bit<16>  payload_length;
    bit<8>   protocol;
    bit<8>   hop_limit;
    bit<128> src_address;
    bit<128> dst_address;
}

struct Headers_t {
    Ethernet_h ethernet;
    IPv6_h     ipv6;
}

parser prs(packet_in p, out Headers_t headers) {
    state start {
        p.extract<Ethernet_h>(headers.ethernet);
        transition select(headers.ethernet.etherType) {
            16w0x86dd: ipv6;
            default: reject;
        }
    }
    state ipv6 {
        p.extract<IPv6_h>(headers.ipv6);
        transition accept;
    }
}

control pipe(inout Headers_t headers, out bool xout) {
    @noWarn("unused") @name(".NoAction") action NoAction_0() {
    }
    @name("pipe.set_flowlabel") action set_flowlabel(bit<20> label) {
        headers.ipv6.ip_version_traffic_class_and_flow_label[31:12] = label;
    }
    @name("pipe.filter_tbl") table filter_tbl_0 {
        key = {
            headers.ipv6.src_address: exact @name("headers.ipv6.src_address") ;
        }
        actions = {
            set_flowlabel();
            @defaultonly NoAction_0();
        }
        const entries = {
                        128w0x200204200380deadbeeff00d0d090001 : set_flowlabel(20w52);
        }
        implementation = hash_table(32w8);
        default_action = NoAction_0();
    }
    @hidden action op_bin82() {
        xout = true;
    }
    @hidden table tbl_op_bin82 {
        actions = {
            op_bin82();
        }
        const default_action = op_bin82();
    }
    apply {
        tbl_op_bin82.apply();
        filter_tbl_0.apply();
    }
}

ebpfFilter<Headers_t>(prs(), pipe()) main;

