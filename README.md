An catagory of UIImageView ,save cache data to the local disk.

usage example:

CGRect frame = {KSMALL_PADDING,KSMALL_PADDING,kUserImageSize};//you can custom the frame as you want

_headImgView = [[UIImageView alloc] initWithFrame:frame];

[_headImgView setImageWithURL:_good.img_url withPlaceHolder:PLACE_HOLDER_IMG_NAME];

get cache data size:
getCacheFileSize(/*app cache dir*/)

clear cache data:
deleteFileAtPath(/*app cache dir*/);
