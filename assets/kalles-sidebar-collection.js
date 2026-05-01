function readMore(position) {
    console.log("aaaa");
    var moreTextElements = document.getElementsByClassName("t4s-more-menu");
    var moreText = moreTextElements[position];
    var svgIcon = document.getElementsByClassName("t4s-toggle-icon")[position];

    var computedStyle = window.getComputedStyle(moreText).display;

    if (computedStyle == "none") {
        svgIcon.classList.add("rotated");
        moreText.style.display = "block";
    } else {
        moreText.style.display = "none";
        svgIcon.classList.remove("rotated");

    }
}