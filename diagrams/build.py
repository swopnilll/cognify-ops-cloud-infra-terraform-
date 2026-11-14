#!/usr/bin/env python3
"""Builds the SVG diagrams used in the README and the notes.

    python3 diagrams/build.py

Each diagram is a function below. Icons come from diagrams/icons/ and are
copied into every SVG, because GitHub does not load external files from inside
an SVG image. No dependencies beyond the Python standard library.
"""

import pathlib
import re

HERE = pathlib.Path(__file__).parent
ICONS = HERE / "icons"

INK = "#232F3E"      # AWS dark blue: text, arrows, the AWS Cloud border
MUTED = "#5F6B7A"    # secondary text
PURPLE = "#8C4FFF"   # VPC
GREEN = "#7AA116"    # public subnet
TEAL = "#00A4A6"     # private subnet, region
BLUE = "#147EBA"     # availability zone
ORANGE = "#ED7100"   # compute
RED = "#D13212"      # avoided / clash
GREY = "#D5DBDB"
GREEN_BG = "#F2F6E8"
TEAL_BG = "#E6F6F7"
PURPLE_BG = "#F2EBFF"
GREY_BG = "#F2F3F3"
RED_BG = "#FDF0EC"

SANS = "'Helvetica Neue', Helvetica, Arial, sans-serif"
MONO = "Menlo, Consolas, 'DejaVu Sans Mono', monospace"


def esc(s):
    return str(s).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


class Diagram:
    def __init__(self, name, width, height, title):
        self.name, self.w, self.h, self.title = name, width, height, title
        self.out = []

    # ---- primitives -------------------------------------------------------

    def rect(self, x, y, w, h, fill="none", stroke=INK, sw=2, dash=None, rx=0):
        d = f' stroke-dasharray="{dash}"' if dash else ""
        s = f' stroke="{stroke}" stroke-width="{sw}"' if stroke else ""
        self.out.append(
            f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}"{s}{d}/>'
        )

    def line(self, x1, y1, x2, y2, stroke=INK, sw=2, dash=None):
        d = f' stroke-dasharray="{dash}"' if dash else ""
        self.out.append(
            f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{stroke}" stroke-width="{sw}"{d}/>'
        )

    def text(self, x, y, s, size=16, weight=400, anchor="start", fill=INK, mono=False, italic=False):
        style = ' font-style="italic"' if italic else ""
        self.out.append(
            f'<text x="{x}" y="{y}" font-family="{MONO if mono else SANS}" font-size="{size}" '
            f'font-weight="{weight}" text-anchor="{anchor}" fill="{fill}"{style}>{esc(s)}</text>'
        )

    def lines(self, x, y, rows, size=14, gap=None, **kw):
        """Several lines of text, top to bottom, starting at baseline y."""
        gap = gap or round(size * 1.35)
        for i, row in enumerate(rows):
            self.text(x, y + i * gap, row, size=size, **kw)

    def icon(self, name, x, y, size):
        src = (ICONS / f"{name}.svg").read_text()
        view = re.search(r'viewBox="([^"]+)"', src).group(1)
        inner = re.search(r"<svg[^>]*>(.*)</svg>", src, re.S).group(1)
        inner = re.sub(r"<title>.*?</title>", "", inner, flags=re.S)
        self.out.append(
            f'<svg x="{x}" y="{y}" width="{size}" height="{size}" viewBox="{view}">{inner}</svg>'
        )

    # ---- AWS-style building blocks ---------------------------------------

    def group(self, x, y, w, h, label, icon=None, color=INK, dash=None, fill="none",
              right=None, isize=32, lsize=16, center=False):
        """A labelled container: AWS Cloud, Region, VPC, subnet, and so on."""
        self.rect(x, y, w, h, fill=fill, stroke=color, sw=2, dash=dash)
        if icon:
            self.icon(icon, x, y, isize)
        if center:
            self.text(x + w / 2, y + 22, label, size=lsize, anchor="middle", fill=color, weight=600)
        else:
            lx = x + (isize + 10 if icon else 12)
            self.text(lx, y + isize / 2 + lsize * 0.36, label, size=lsize, weight=600)
        if right:
            self.text(x + w - 12, y + isize / 2 + lsize * 0.36, right, size=lsize,
                      weight=700, anchor="end", mono=True)

    def node(self, icon, cx, y, labels, size=64, lsize=14):
        """An icon with a centred label under it."""
        self.icon(icon, cx - size / 2, y, size)
        for i, row in enumerate(labels):
            self.text(cx, y + size + 20 + i * round(lsize * 1.3), row, size=lsize,
                      anchor="middle", weight=600 if i == 0 else 400,
                      fill=INK if i == 0 else MUTED)

    def arrow(self, pts, color=INK, dash=None, sw=2):
        """A line through pts with an arrowhead at the last point."""
        (x1, y1), (x2, y2) = pts[-2], pts[-1]
        dx, dy = x2 - x1, y2 - y1
        n = (dx * dx + dy * dy) ** 0.5
        ux, uy = dx / n, dy / n
        bx, by = x2 - ux * 11, y2 - uy * 11           # base of the arrowhead
        px, py = -uy * 5.5, ux * 5.5
        body = pts[:-1] + [(bx, by)]
        d = f' stroke-dasharray="{dash}"' if dash else ""
        p = " ".join(f"{x:.1f},{y:.1f}" for x, y in body)
        self.out.append(
            f'<polyline points="{p}" fill="none" stroke="{color}" stroke-width="{sw}" '
            f'stroke-linejoin="round"{d}/>'
        )
        self.out.append(
            f'<polygon points="{x2:.1f},{y2:.1f} {bx + px:.1f},{by + py:.1f} '
            f'{bx - px:.1f},{by - py:.1f}" fill="{color}"/>'
        )

    def badge(self, n, cx, cy, r=15):
        """A numbered step marker. The numbers are explained next to the image."""
        self.out.append(f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{INK}" stroke="#fff" stroke-width="2"/>')
        self.text(cx, cy + 5, n, size=15, weight=700, anchor="middle", fill="#fff")

    def brace(self, x1, x2, y, down=True, color=INK):
        """A square bracket spanning x1..x2, with a tick pointing at the label."""
        t = 8 if down else -8
        mid = (x1 + x2) / 2
        self.out.append(
            f'<path d="M{x1},{y} v{t} H{x2} v{-t} M{mid},{y + t} v{t}" fill="none" '
            f'stroke="{color}" stroke-width="2"/>'
        )

    def save(self):
        body = "\n".join(self.out)
        svg = (
            f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {self.w} {self.h}" '
            f'width="{self.w}" height="{self.h}" role="img" aria-label="{esc(self.title)}">\n'
            f"<title>{esc(self.title)}</title>\n"
            f'<rect width="{self.w}" height="{self.h}" fill="#fff"/>\n{body}\n</svg>\n'
        )
        path = HERE / f"{self.name}.svg"
        path.write_text(svg)
        print(f"wrote {path.relative_to(HERE.parent)}")


# ---------------------------------------------------------------------------
# 01 – CIDR plan
# ---------------------------------------------------------------------------

def address_plan():
    d = Diagram("01-address-plan", 1200, 700,
                "The Cognify VPC: 10.30.0.0/16 with a public and a private /24 subnet in each of two availability zones")
    d.group(20, 20, 1160, 660, "AWS Cloud", icon="AWSCloudlogo", isize=40, lsize=17)
    d.group(60, 80, 1080, 580, "Region: ap-southeast-2 (Sydney)", icon="Region", color=TEAL, dash="6 4")
    d.group(100, 135, 1000, 500, "cognify-prod-vpc", icon="VirtualprivatecloudVPC", color=PURPLE,
            right="10.30.0.0/16")
    d.badge(1, 940, 151)

    for x, az in ((130, "a"), (615, "b")):
        d.group(x, 195, 455, 415, f"Availability Zone ap-southeast-2{az}", color=BLUE, dash="6 4",
                center=True, lsize=15)

    def subnet(x, y, name, cidr, public, empty_note=None):
        color, bg = (GREEN, GREEN_BG) if public else (TEAL, TEAL_BG)
        d.group(x, y, 405, 160, name, icon="Publicsubnet" if public else "Privatesubnet",
                color=color, fill=bg, right=cidr)
        d.text(x + 393, y + 146, "251 usable addresses", size=13, anchor="end", fill=MUTED)
        if empty_note:
            d.text(x + 202, y + 88, "empty", size=15, anchor="middle", fill=MUTED, italic=True)
            d.text(x + 202, y + 108, empty_note, size=13, anchor="middle", fill=MUTED, italic=True)

    subnet(155, 240, "public-a", "10.30.0.0/24", True)
    d.icon("AmazonEC2Instance", 185, 292, 56)
    d.text(256, 316, "EC2 server", size=15, weight=600)
    d.text(256, 336, "the only thing planned for this VPC", size=13, fill=MUTED)
    subnet(640, 240, "public-b", "10.30.1.0/24", True, "reserved: a load balancer needs a second AZ")
    subnet(155, 425, "private-a", "10.30.10.0/24", False, "reserved for a database")
    subnet(640, 425, "private-b", "10.30.11.0/24", False, "reserved for a database")

    d.badge(4, 600, 213)
    d.badge(2, 600, 320)
    d.badge(3, 600, 505)
    d.save()


def reading_an_address():
    d = Diagram("01-reading-an-address", 1000, 470,
                "How to read the address 10.30.10.57: VPC 10.30, subnet 10, host 57")
    octets = [("10", PURPLE, PURPLE_BG), ("30", PURPLE, PURPLE_BG), ("10", TEAL, TEAL_BG), ("57", MUTED, GREY_BG)]
    xs = [170, 350, 530, 710]
    for x, (val, color, bg) in zip(xs, octets):
        d.rect(x, 30, 150, 90, fill=bg, stroke=color, rx=6)
        d.text(x + 75, 93, val, size=50, weight=700, anchor="middle", mono=True)
    for x in xs[:-1]:
        d.text(x + 165, 100, ".", size=50, weight=700, anchor="middle", mono=True)

    d.brace(170, 500, 130, color=PURPLE)
    d.text(335, 170, "the VPC: 10.30.0.0/16", size=17, weight=700, anchor="middle")
    d.lines(335, 192, ["the same for every address", "in this VPC"], size=14, anchor="middle", fill=MUTED)

    d.brace(530, 680, 130, color=TEAL)
    d.text(605, 170, "subnet 10", size=17, weight=700, anchor="middle")
    d.lines(605, 192, ["10–19 = private tier", "first in the tier = AZ a"], size=14, anchor="middle", fill=MUTED)

    d.brace(710, 860, 130, color=MUTED)
    d.text(785, 170, "host 57", size=17, weight=700, anchor="middle")
    d.lines(785, 192, ["one of the 251 usable", "addresses in the subnet"], size=14, anchor="middle", fill=MUTED)

    # The same address as 32 bits.
    bits = "".join(f"{n:08b}" for n in (10, 30, 10, 57))
    x0, y0, cw, ch = 148, 300, 22, 30
    for i, b in enumerate(bits):
        color, bg = (PURPLE, PURPLE_BG) if i < 16 else (TEAL, TEAL_BG) if i < 24 else (MUTED, GREY_BG)
        d.rect(x0 + i * cw, y0, cw, ch, fill=bg, stroke=color, sw=1)
        d.text(x0 + i * cw + cw / 2, y0 + 20, b, size=13, anchor="middle", mono=True)
    d.text(x0 - 12, y0 + 20, "in bits", size=14, anchor="end", fill=MUTED)
    for bit, label in ((16, "/16"), (24, "/24")):
        x = x0 + bit * cw
        d.line(x, y0 - 22, x, y0 + ch + 8, sw=2)
        d.text(x, y0 - 28, label, size=15, weight=700, anchor="middle", mono=True)

    d.brace(x0, x0 + 16 * cw, y0 + ch + 10, color=PURPLE)
    d.text(x0 + 8 * cw, y0 + ch + 48, "16 bits fixed by the VPC", size=14, weight=600, anchor="middle")
    d.brace(x0 + 16 * cw, x0 + 24 * cw, y0 + ch + 10, color=TEAL)
    d.text(x0 + 20 * cw, y0 + ch + 48, "8 bits: which subnet", size=14, weight=600, anchor="middle")
    d.text(x0 + 20 * cw, y0 + ch + 67, "256 possible /24s", size=13, anchor="middle", fill=MUTED)
    d.brace(x0 + 24 * cw, x0 + 32 * cw, y0 + ch + 10, color=MUTED)
    d.text(x0 + 28 * cw, y0 + ch + 48, "8 bits: which host", size=14, weight=600, anchor="middle")
    d.text(x0 + 28 * cw, y0 + ch + 67, "256 addresses each", size=13, anchor="middle", fill=MUTED)
    d.text(500, 440, "A /24 inside a /16 puts the subnet number in an octet of its own, so it can be read without any maths.",
           size=14, anchor="middle", fill=MUTED, italic=True)
    d.save()


def address_space():
    d = Diagram("01-address-space", 1100, 330,
                "The 256 possible /24 subnets in 10.30.0.0/16: four in use, the rest of each tier reserved, 236 unassigned")
    d.text(40, 36, "10.30.", size=20, weight=700, mono=True)
    d.text(112, 36, "X", size=20, weight=700, mono=True, fill=RED)
    d.text(124, 36, ".0/24", size=20, weight=700, mono=True)
    d.text(200, 36, "the third octet X is the subnet number", size=15, fill=MUTED)

    x0, y0, cw, ch = 40, 110, 40, 56
    used = {0: "a", 1: "b", 10: "a", 11: "b"}
    for n in range(20):
        color, bg = (GREEN, GREEN_BG) if n < 10 else (TEAL, TEAL_BG)
        x = x0 + n * cw
        if n in used:
            d.rect(x, y0, cw, ch, fill=color, stroke=color)
            d.text(x + cw / 2, y0 + 35, n, size=17, weight=700, anchor="middle", fill="#fff", mono=True)
            d.text(x + cw / 2, y0 + ch + 20, f"AZ {used[n]}", size=13, weight=600, anchor="middle")
        else:
            d.rect(x, y0, cw, ch, fill=bg, stroke=color)
            d.text(x + cw / 2, y0 + 35, n, size=15, anchor="middle", fill=MUTED, mono=True)
    d.rect(850, y0, 210, ch, fill=GREY_BG, stroke=GREY)
    d.text(955, y0 + 35, "20 – 255", size=17, weight=700, anchor="middle", mono=True, fill=MUTED)

    d.brace(x0, x0 + 10 * cw, y0 - 10, down=False, color=GREEN)
    d.text(x0 + 5 * cw, y0 - 48, "public tier: 0–9", size=15, weight=700, anchor="middle")
    d.text(x0 + 5 * cw, y0 - 30, "10.30.0.0 – 10.30.9.255", size=12, anchor="middle", fill=MUTED, mono=True)
    d.brace(x0 + 10 * cw, x0 + 20 * cw, y0 - 10, down=False, color=TEAL)
    d.text(x0 + 15 * cw, y0 - 48, "private tier: 10–19", size=15, weight=700, anchor="middle")
    d.text(x0 + 15 * cw, y0 - 30, "10.30.10.0 – 10.30.19.255", size=12, anchor="middle", fill=MUTED, mono=True)
    d.brace(850, 1060, y0 - 10, down=False, color=MUTED)
    d.text(955, y0 - 48, "unassigned", size=15, weight=700, anchor="middle")
    d.text(955, y0 - 30, "10.30.20.0 – 10.30.255.255", size=12, anchor="middle", fill=MUTED, mono=True)

    # Legend
    y = 258
    d.rect(40, y, 22, 22, fill=GREEN, stroke=GREEN)
    d.rect(66, y, 22, 22, fill=TEAL, stroke=TEAL)
    d.text(98, y + 16, "in use: 4 subnets", size=14)
    d.rect(300, y, 22, 22, fill=GREEN_BG, stroke=GREEN)
    d.rect(326, y, 22, 22, fill=TEAL_BG, stroke=TEAL)
    d.text(358, y + 16, "free, kept for that tier: 8 + 8", size=14)
    d.rect(650, y, 22, 22, fill=GREY_BG, stroke=GREY)
    d.text(682, y + 16, "free, no purpose yet: 236 more /24s", size=14)
    d.text(40, 312, "A third AZ would take the next number in each tier: 2 and 12.", size=14, fill=MUTED, italic=True)
    d.save()


def reserved_addresses():
    d = Diagram("01-reserved-addresses", 1000, 250,
                "The five addresses AWS reserves in every subnet, shown for 10.30.0.0/24")
    d.text(40, 36, "public-a", size=17, weight=700)
    d.text(122, 36, "10.30.0.0/24", size=17, weight=700, mono=True)
    d.text(262, 36, "256 addresses − 5 reserved by AWS = 251 usable", size=15, fill=MUTED)

    y, h = 70, 64
    cells = [
        (40, 90, ".0", ["network", "address"]),
        (130, 90, ".1", ["VPC", "router"]),
        (220, 90, ".2", ["DNS", "resolver"]),
        (310, 90, ".3", ["reserved for", "future use"]),
        (850, 90, ".255", ["broadcast", "(unused in a VPC)"]),
    ]
    for x, w, label, note in cells:
        d.rect(x, y, w, h, fill=RED_BG, stroke=RED)
        d.text(x + w / 2, y + 40, label, size=20, weight=700, anchor="middle", mono=True)
        d.lines(x + w / 2, y + h + 22, note, size=13, anchor="middle", fill=MUTED)
    d.rect(400, y, 450, h, fill=GREEN_BG, stroke=GREEN)
    d.text(625, y + 40, ".4  –  .254", size=20, weight=700, anchor="middle", mono=True)
    d.text(625, y + h + 22, "251 addresses for instances, load balancers, databases", size=13,
           anchor="middle", fill=MUTED)

    d.text(40, 222, "The same five are taken in every subnet of every VPC, whatever its size.",
           size=14, fill=MUTED, italic=True)
    d.save()


def choosing_the_range():
    d = Diagram("01-choosing-the-range", 1100, 500,
                "The three private IPv4 ranges and why the Cognify VPC uses 10.30.0.0/16")

    def row(y, cidr, size, verdict, color, bg, chips):
        d.rect(30, y, 1040, 130, fill=bg, stroke=color, rx=6)
        d.text(54, y + 40, cidr, size=22, weight=700, mono=True)
        d.text(54, y + 62, size, size=13, fill=MUTED)
        d.text(1046, y + 36, verdict, size=15, weight=700, anchor="end", fill=color)
        x = 54
        for label, note, solid in chips:
            w = max(len(label) * 10.2, len(note) * 6.6) + 28
            if solid:
                d.rect(x, y + 76, w, 42, fill=PURPLE, stroke=PURPLE, rx=4)
                fg, fg2 = "#fff", "#fff"
            else:
                d.rect(x, y + 76, w, 42, fill="#fff", stroke=GREY, rx=4)
                fg, fg2 = INK, MUTED
            d.text(x + 14, y + 94, label, size=14, weight=700, mono=True, fill=fg)
            d.text(x + 14, y + 111, note, size=12, fill=fg2)
            x += w + 14

    row(20, "10.0.0.0/8", "16.7 million addresses", "CHOSEN", GREEN, GREEN_BG, [
        ("10.0.0.0/16", "the default everyone picks", False),
        ("10.20.0.0/16", "already used by another VPC", False),
        ("10.30.0.0/16", "the Cognify VPC", True),
        ("10.40, 10.50 …", "free for future VPCs", False),
    ])
    row(170, "172.16.0.0/12", "1 million addresses", "AVOIDED: clashes with Docker", RED, RED_BG, [
        ("172.17.0.0/16", "Docker's default bridge network", False),
        ("172.18 – 172.31", "taken by Docker Compose networks, one each", False),
    ])
    row(320, "192.168.0.0/16", "65,536 addresses", "AVOIDED: clashes with home networks", RED, RED_BG, [
        ("192.168.0.0/24", "most home routers", False),
        ("192.168.1.0/24", "most of the rest", False),
    ])
    d.text(30, 482, "A VPC must use private (RFC 1918) space. Two networks can only be connected if their ranges do not overlap.",
           size=14, fill=MUTED, italic=True)
    d.save()


# ---------------------------------------------------------------------------
# README
# ---------------------------------------------------------------------------

def target_design():
    d = Diagram("target-design", 1200, 640,
                "Target design: one EC2 instance running Docker Compose in a public subnet, with SQS, IAM, a budget alert and S3 for Terraform state")
    d.node("User", 75, 246, ["User"], size=48)
    d.node("Internet", 75, 356, ["OpenAI API"], size=48)

    d.group(150, 20, 1030, 600, "AWS Cloud", icon="AWSCloudlogo", isize=40, lsize=17)
    d.group(190, 80, 640, 510, "cognify-prod-vpc", icon="VirtualprivatecloudVPC", color=PURPLE,
            right="10.30.0.0/16")
    d.group(260, 135, 540, 330, "public-a", icon="Publicsubnet", color=GREEN, fill=GREEN_BG,
            right="10.30.0.0/24")
    d.group(290, 185, 480, 255, "EC2 server: t4g.small, Docker Compose", icon="AmazonEC2",
            color=ORANGE, fill="#fff", lsize=15)

    def container(x, y, name, note):
        d.rect(x, y, 190, 70, fill="#fff", stroke=INK, sw=1.5, rx=4)
        d.icon("AmazonElasticContainerServiceContainer1", x + 10, y + 17, 36)
        d.text(x + 56, y + 31, name, size=15, weight=700)
        d.text(x + 56, y + 50, note, size=12, fill=MUTED)

    container(315, 235, "web", "Caddy + React build")
    container(555, 235, "api", "Express")
    container(315, 345, "embedding", "queue worker")
    container(555, 345, "db", "Postgres 17 + pgvector")

    for x, name, cidr, public in ((260, "public-b", "10.30.1.0/24", True),
                                  (445, "private-a", "10.30.10.0/24", False),
                                  (630, "private-b", "10.30.11.0/24", False)):
        color, bg = (GREEN, GREEN_BG) if public else (TEAL, TEAL_BG)
        d.rect(x, 490, 170, 76, fill=bg, stroke=color)
        d.icon("Publicsubnet" if public else "Privatesubnet", x, 490, 24)
        d.text(x + 32, 507, name, size=13, weight=600)
        d.text(x + 85, 536, cidr, size=13, weight=700, anchor="middle", mono=True)
        d.text(x + 85, 554, "empty, reserved", size=12, anchor="middle", fill=MUTED, italic=True)

    # Internet gateway sits on the VPC border.
    d.rect(166, 246, 48, 48, fill="#fff", stroke=None)
    d.icon("AmazonVPCInternetGateway", 166, 246, 48)
    d.rect(160, 299, 60, 34, fill="#fff", stroke=None)
    d.text(190, 312, "Internet", size=12, anchor="middle", weight=600)
    d.text(190, 327, "gateway", size=12, anchor="middle", weight=600)

    d.node("AmazonSimpleQueueService", 1035, 140, ["Amazon SQS", "embedding-jobs + DLQ"])
    d.node("AWSIdentityandAccessManagement", 975, 310, ["IAM role", "queue access,", "no stored keys"], size=56, lsize=13)
    d.node("AWSBudgets", 1095, 310, ["AWS Budgets", "email alert"], size=56, lsize=13)
    d.node("AmazonSimpleStorageService", 1035, 470, ["Amazon S3", "Terraform state"], size=56, lsize=13)

    d.arrow([(101, 270), (164, 270)])
    d.arrow([(216, 270), (315, 270)])
    d.arrow([(505, 270), (555, 270)])
    d.arrow([(650, 305), (650, 345)])
    d.arrow([(745, 255), (870, 255), (870, 165), (1003, 165)])
    d.arrow([(1003, 185), (895, 185), (895, 452), (410, 452), (410, 415)])
    d.arrow([(505, 380), (555, 380)])
    d.arrow([(315, 380), (101, 380)], dash="6 4")

    d.badge(1, 132, 248)
    d.badge(2, 238, 248)
    d.badge(3, 530, 248)
    d.badge(4, 674, 325)
    d.badge(5, 870, 210)
    d.badge(6, 895, 330)
    d.badge(7, 238, 358)
    d.save()


if __name__ == "__main__":
    address_plan()
    reading_an_address()
    address_space()
    reserved_addresses()
    choosing_the_range()
    target_design()
