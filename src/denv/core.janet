(import src/denv/util/fs)

(defn cmsg [t msg]
  (let [reset "\e[39;49m"]
    (case t
      :succ (string "\e[32m" msg reset)
      :err  (string "\e[31m" msg reset)
      :info (string reset msg reset))))
(defn cinfo [msg] (cmsg :info msg))
(defn cerr [msg] (cmsg :err msg))
(defn csucc [msg] (cmsg :succ msg))

(def distro
  (let [e? (fn [p] (fs/exists? p))]
    (cond
      (e? "/etc/lsb-release") :ubuntu
      (e? "/etc/debian_release") :debian
      (e? "/etc/arch-release") :archlinux
      (= "mac" (os/which)) :mac
      :else :unknown)))

(def cfg
  # TODO: make each value a def, check for config file at the beginning of the file.
  (let [denv (fn [v] (-> v os/getenv (string "/denv") fs/ensure))
        cfg  (->> [(string (denv "XDG_DATA_HOME") "/config.janet")
                   (string (denv "XDG_CONFIG_HOME") "/config.janet")
                   (string (os/getenv "HOME") "/.denv/config.janet")
                   (string (os/cwd) "/env.janet")]
                  # TODO: return most recent one.
                  (filter fs/readable?)
                  (array/peek))
        user (if (nil? cfg)
               (error (cerr "denv configuration file can't be found."))
               (-> cfg slurp parse))
        root (fn [&opt p]
               (string (os/getenv "HOME") "/" (user :path)
                       (when p (string "/" p))))]
    {:user/remote-repo (user :repo)
     :user/local-repo (root)
     :user/profiles (root (or (user :profiles) "profiles"))
     :user/deps (root (or (user :deps) "local"))
     :user/resources (root (or (user :resources) "store"))
     :user/init (root (get-in user [:init distro]))
     :user/pass (user :pass)
     :user/distro distro
     :denv/cache-dir (denv "XDG_CACHE_HOME")
     :denv/data-dir (denv "XDG_DATA_HOME")
     :denv/debug (= 1 (os/getenv "DENV_DEBUG"))
     :denv/deps-dir (fs/ensure (string (denv "XDG_DATA_HOME") "/deps"))
     :denv/log-dir (fs/ensure (string (denv "XDG_DATA_HOME") "/logs"))}))

(defn datetime
  ```
  Returns a formated string of the current data and time.
  ```
  []
  (let [date (os/date (os/time) true)
        f (fn [d] (string/slice (string "0" d) -3))
        Y (date :year)
        M (f (date :month))
        d (f (date :month-day))
        h (f (date :hours))
        m (f (date :minutes))]
    (string Y "-" M "-" d "-" h ":" m)))

(defn update-registry
  ```
  Post function used after "req" to update logs and print msg to the user.
  # TODO: sort logs/use array
  ```
  [aspect xs]
  (def- path (string/format "%s/%ss.janet" (cfg :denv/log-dir) (string aspect)))
  (def- content (slurp (fs/ensure path)))
  (def- logged (if (not (empty? content)) (parse content) @{}))
  (put logged (keyword (datetime)) xs)
  (spit path (string/format "%m" logged)))
