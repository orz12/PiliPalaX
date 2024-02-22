class MyEmote {
  Setting? setting;
  List<Packages>? packages;

  MyEmote({this.setting, this.packages});

  MyEmote.fromJson(Map<String, dynamic> json) {
    setting =
    json['setting'] != null ? Setting.fromJson(json['setting']) : null;
    if (json['packages'] != null) {
      packages = <Packages>[];
      json['packages'].forEach((v) {
        packages!.add(Packages.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (setting != null) {
      data['setting'] = setting!.toJson();
    }
    if (packages != null) {
      data['packages'] = packages!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Setting {
  int? recentLimit;
  int? attr;
  int? focusPkgId;
  String? schema;

  Setting({this.recentLimit, this.attr, this.focusPkgId, this.schema});

  Setting.fromJson(Map<String, dynamic> json) {
    recentLimit = json['recent_limit'];
    attr = json['attr'];
    focusPkgId = json['focus_pkg_id'];
    schema = json['schema'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['recent_limit'] = recentLimit;
    data['attr'] = attr;
    data['focus_pkg_id'] = focusPkgId;
    data['schema'] = schema;
    return data;
  }
}

class Packages {
  int? id;
  String? text;
  String? url;
  int? mtime;
  int? type;
  int? attr;
  PackagesMeta? meta;
  List<Emote>? emote;
  PackagesFlags? flags;
  dynamic label;
  String? packageSubTitle;
  int? refMid;

  Packages(
      {this.id,
        this.text,
        this.url,
        this.mtime,
        this.type,
        this.attr,
        this.meta,
        this.emote,
        this.flags,
        this.label,
        this.packageSubTitle,
        this.refMid});

  Packages.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    text = json['text'];
    url = json['url'];
    mtime = json['mtime'];
    type = json['type'];
    attr = json['attr'];
    meta = json['meta'] != null ? PackagesMeta.fromJson(json['meta']) : null;
    if (json['emote'] != null) {
      emote = <Emote>[];
      json['emote'].forEach((v) {
        emote!.add(Emote.fromJson(v));
      });
    }
    flags = json['flags'] != null ? PackagesFlags.fromJson(json['flags']) : null;
    label = json['label'];
    packageSubTitle = json['package_sub_title'];
    refMid = json['ref_mid'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['text'] = text;
    data['url'] = url;
    data['mtime'] = mtime;
    data['type'] = type;
    data['attr'] = attr;
    if (meta != null) {
      data['meta'] = meta!.toJson();
    }
    if (emote != null) {
      data['emote'] = emote!.map((v) => v.toJson()).toList();
    }
    if (flags != null) {
      data['flags'] = flags!.toJson();
    }
    data['label'] = label;
    data['package_sub_title'] = packageSubTitle;
    data['ref_mid'] = refMid;
    return data;
  }
}

class PackagesMeta {
  int? size;
  int? itemId;

  PackagesMeta({this.size, this.itemId});

  PackagesMeta.fromJson(Map<String, dynamic> json) {
    size = json['size'];
    itemId = json['item_id'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['size'] = size;
    data['item_id'] = itemId;
    return data;
  }
}

class Emote {
  int? id;
  int? packageId;
  String? text;
  String? url;
  int? mtime;
  int? type;
  int? attr;
  EmoteMeta? meta;
  EmoteFlags? flags;
  dynamic activity;
  String? gifUrl;

  Emote(
      {this.id,
        this.packageId,
        this.text,
        this.url,
        this.mtime,
        this.type,
        this.attr,
        this.meta,
        this.flags,
        this.activity,
        this.gifUrl});

  Emote.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    packageId = json['package_id'];
    text = json['text'];
    url = json['url'];
    mtime = json['mtime'];
    type = json['type'];
    attr = json['attr'];
    meta = json['meta'] != null ? EmoteMeta.fromJson(json['meta']) : null;
    flags = json['flags'] != null ? EmoteFlags.fromJson(json['flags']) : null;
    activity = json['activity'];
    gifUrl = json['gif_url'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['package_id'] = packageId;
    data['text'] = text;
    data['url'] = url;
    data['mtime'] = mtime;
    data['type'] = type;
    data['attr'] = attr;
    if (meta != null) {
      data['meta'] = meta!.toJson();
    }
    if (flags != null) {
      data['flags'] = flags!.toJson();
    }
    data['activity'] = activity;
    data['gif_url'] = gifUrl;
    return data;
  }
}

class EmoteMeta {
  int? size;
  List<String>? suggest;
  String? alias;
  String? gifUrl;

  EmoteMeta({this.size, this.suggest, this.alias, this.gifUrl});

  EmoteMeta.fromJson(Map<String, dynamic> json) {
    size = json['size'];
    suggest = json['suggest'].cast<String>();
    alias = json['alias'];
    gifUrl = json['gif_url'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['size'] = size;
    data['suggest'] = suggest;
    data['alias'] = alias;
    data['gif_url'] = gifUrl;
    return data;
  }
}

class EmoteFlags {
  bool? unlocked;

  EmoteFlags({this.unlocked});

  EmoteFlags.fromJson(Map<String, dynamic> json) {
    unlocked = json['unlocked'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['unlocked'] = unlocked;
    return data;
  }
}

class PackagesFlags {
  bool? added;
  bool? preview;

  PackagesFlags({this.added, this.preview});

  PackagesFlags.fromJson(Map<String, dynamic> json) {
    added = json['added'];
    preview = json['preview'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['added'] = added;
    data['preview'] = preview;
    return data;
  }
}
